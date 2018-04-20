package AnyJob::Semaphore::Engine;

###############################################################################
# Class used to manage distributed semaphore instances. It also loads and manages all required lua scripts and
# does cleaning of timeouted client enterings.
#
# Author:       LightStar
# Created:      04.04.2018
# Last update:  20.04.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_LIMIT);
use AnyJob::Semaphore::Instance;

###############################################################################
# Lua script used by client to enter into critical section guarded by semaphore.
#
# KEYS[1] - key with semaphore value.
# KEYS[2] - key with semaphore reading value.
# KEYS[3] - key with sorted set which is filled by active client names.
# KEYS[4] - key with set which is filled by names of clients waiting for critical section to become available.
# ARGV[1] - string client name.
# ARGV[2] - integer maximum semaphore value.
# ARGV[3] - integer unix timestamp when this client activity inside critical section will timeout.
use constant ENTER_SCRIPT => <<'EOF';
    if tonumber(redis.call('get',KEYS[1]) or '0') + (tonumber(redis.call('get',KEYS[2]) or '0') > 0 and 1 or 0) >= tonumber(ARGV[2]) then
        redis.call('sadd', KEYS[4], ARGV[1])
        return 0
    elseif tonumber(redis.call('zadd', KEYS[3], ARGV[3], ARGV[1])) > 0 then
        redis.call('incr', KEYS[1])
    end
    return 1
EOF

###############################################################################
# Lua script used by reading client to enter into critical section guarded by semaphore.
# All reading clients are counted as one.
#
# KEYS[1] - key with semaphore value.
# KEYS[2] - key with semaphore reading value.
# KEYS[3] - key with sorted set which is filled by active client names.
# KEYS[4] - key with set which is filled by names of clients waiting for critical section to become available.
# ARGV[1] - string client name.
# ARGV[2] - integer maximum semaphore value.
# ARGV[3] - integer unix timestamp when this client activity inside critical section will timeout.
use constant ENTER_READ_SCRIPT => <<'EOF';
    if tonumber(redis.call('get',KEYS[1]) or '0') >= tonumber(ARGV[2]) then
        redis.call('sadd', KEYS[4], ARGV[1])
        return 0
    elseif tonumber(redis.call('zadd', KEYS[3], ARGV[3], ARGV[1])) > 0 then
        redis.call('incr', KEYS[2])
    end
    return 1
EOF

###############################################################################
# Lua script used by client to exit from critical section guarded by semaphore.
#
# KEYS[1] - key with semaphore value.
# KEYS[2] - key with semaphore reading value.
# KEYS[3] - key with sorted set which is filled by active client names.
# KEYS[4] - key with set which is filled by names of clients waiting for critical section to become available.
# ARGV[1] - string client name.
use constant EXIT_SCRIPT => <<'EOF';
    if tonumber(redis.call('zrem', KEYS[3], ARGV[1])) == 0 then
        return 0
    end
    if tonumber(redis.call('decr', KEYS[1])) < 0 then
        redis.call('set', KEYS[1], '0')
    else
        local clients = redis.call('smembers', KEYS[4])
        if table.getn(clients) > 0 then
            for i, client in ipairs(clients) do
                redis.call('rpush', 'anyjob:semq:' .. client, '')
            end
            redis.call('del', KEYS[4])
        end
    end
    return 1
EOF

###############################################################################
# Lua script used by reading client to exit from critical section guarded by semaphore.
# All reading clients are counted as one.
#
# KEYS[1] - key with semaphore value.
# KEYS[2] - key with semaphore reading value.
# KEYS[3] - key with sorted set which is filled by active client names.
# KEYS[4] - key with set which is filled by names of clients waiting for critical section to become available.
# ARGV[1] - string client name.
use constant EXIT_READ_SCRIPT => <<'EOF';
    if tonumber(redis.call('zrem', KEYS[3], ARGV[1])) == 0 then
       return 0
    end
    local count = tonumber(redis.call('decr', KEYS[2]))
    if count < 0 then
        redis.call('set', KEYS[2], '0')
    elseif count == 0 then
        local clients = redis.call('smembers', KEYS[4])
        if table.getn(clients) > 0 then
            for i, client in ipairs(clients) do
                redis.call('rpush', 'anyjob:semq:' .. client, '')
            end
            redis.call('del', KEYS[4])
        end
    end
    return 1
EOF

###############################################################################
# Lua script used by clean all timeouted client enterings into all semaphores.
#
# KEYS[1] - key with semaphore value.
# ARGV[1] - integer current time in unix timestamp format.
# ARGV[2] - integer limit of processed timeouted enterings.
use constant CLEAN_SCRIPT => <<'EOF';
    local clients = redis.call('zrangebyscore', KEYS[1], '-inf', ARGV[1], 'limit', 0, ARGV[2])
    for i, clientFull in ipairs(clients) do
        redis.call('zrem', KEYS[1], clientFull)

        local colIndex = string.find(clientFull, ':')
        local key = string.sub(clientFull, 1, colIndex - 1)
        local client = string.sub(clientFull, colIndex + 1, -1)
        local signalToWaiting = false

        if string.find(client, ':r') == nil then
            if tonumber(redis.call('decr', 'anyjob:sem:' .. key)) < 0 then
                redis.call('set', 'anyjob:sem:' .. key, '0')
            else
                signalToWaiting = true
            end
        else
            local count = tonumber(redis.call('decr', 'anyjob:semr:' .. key))
            if count < 0 then
                redis.call('set', 'anyjob:sem:' .. key, '0')
            elseif count == 0 then
                signalToWaiting = true
            end
        end

        if signalToWaiting then
            local waitingClients = redis.call('smembers', 'anyjob:sem:' .. key .. ':wait')
            if table.getn(waitingClients) > 0 then
                for i, waitingClient in ipairs(waitingClients) do
                    redis.call('rpush', 'anyjob:semq:' .. waitingClient, '')
                end
                redis.call('del', 'anyjob:sem:' .. key .. ':wait')
            end
        end
    end
    return table.getn(clients)
EOF

###############################################################################
# Construct new AnyJob::Semaphore::Engine object.
#
# Arguments:
#     parent - parent component which is usually subclassed from AnyJob::Base class.
# Returns:
#     AnyJob::Semaphore::Engine object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    $self->{scripts} = {};
    $self->{scripts}->{enter} = $self->redis->script('load', ENTER_SCRIPT);
    $self->{scripts}->{enterRead} = $self->redis->script('load', ENTER_READ_SCRIPT);
    $self->{scripts}->{exit} = $self->redis->script('load', EXIT_SCRIPT);
    $self->{scripts}->{exitRead} = $self->redis->script('load', EXIT_READ_SCRIPT);
    $self->{scripts}->{clean} = $self->redis->script('load', CLEAN_SCRIPT);

    $self->{semaphores} = {};

    my $nodeConfig = $self->config->getNodeConfig() || {};
    $self->{clean_limit} = $nodeConfig->{semaphore_clean_limit} || $self->config->clean_limit || DEFAULT_CLEAN_LIMIT;

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually subclassed from AnyJob::Base object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Returns:
#     Redis object.
#
sub redis {
    my $self = shift;
    return $self->{parent}->redis;
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{parent}->config;
}

###############################################################################
# Write debug message to log.
#
# Arguments:
#     message - string debug message.
#
sub debug {
    my $self = shift;
    my $message = shift;
    $self->{parent}->debug($message);
}

###############################################################################
# Write error message to log.
#
# Arguments:
#     message - string error message.
#
sub error {
    my $self = shift;
    my $message = shift;
    $self->{parent}->error($message);
}

###############################################################################
# Get lua script sha hash to use in the 'evalsha' redis command.
#
# Arguments:
#     name - string script name.
# Returns:
#     string script sha1 hash or undef if there are no such script.
#
sub getScriptSha {
    my $self = shift;
    my $name = shift;
    return $self->{scripts}->{$name};
}

###############################################################################
# Get semaphore object instance with specified name.
#
# Arguments:
#     name - string semaphore name.
# Returns:
#     AnyJob::Semaphore::Instance object.
#
sub getSemaphore {
    my $self = shift;
    my $name = shift;

    if (exists($self->{semaphores}->{$name})) {
        return $self->{semaphores}->{$name};
    }

    my $config = $self->config->getSemaphoreConfig($name) || {};
    $self->{semaphores}->{$name} = AnyJob::Semaphore::Instance->new(
        engine => $self,
        name   => $name,
        config => $config
    );

    return $self->{semaphores}->{$name};
}

###############################################################################
# Clean timeouted enterings by clients.
#
# Returns:
#     integer count of timeouted enterings.
#
sub cleanTimeoutedClients {
    my $self = shift;
    return $self->redis->evalsha($self->getScriptSha('clean'), 1, 'anyjob:sem:clients', time(), $self->{clean_limit});
}

1;
