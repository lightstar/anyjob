package AnyJob::Semaphore;

###############################################################################
# Class used to manage distributed semaphore. Semaphore is an entity which is used to guard critical sections and
# can be entered by different clients limited number of times. Clients can be regular (writing) and reading ones.
# Any number of enterings by reading clients are counted as one.
#
# So ordinary usecase of semaphore is such as that: create semaphore object, enter it before critical section and
# exit it after. If you forget to exit semaphore or critical section unexpectedly crushes, semaphore will automatically
# timeout sometime later.
#
# If you can't enter semaphore right now, you can use waiting queue to receive signal when semaphore will be freed.
#
# Author:       LightStar
# Created:      27.03.2018
# Last update:  03.04.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_TIMEOUT);

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
    elseif tonumber(redis.call('zadd', KEYS[3], ARGV[3], ARGV[1])) > 0 then
        redis.call('incr', KEYS[1])
        return 1
    end
    return 0
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
    elseif tonumber(redis.call('zadd', KEYS[3], ARGV[3], ARGV[1])) > 0 then
        redis.call('incr', KEYS[2])
        return 1
    end
    return 0
EOF

###############################################################################
# Lua script used by client to exit from critical section guarded by semaphore.
#
# KEYS[1] - key with semaphore value.
# KEYS[2] - key with semaphore reading value.
# KEYS[3] - key with sorted set which is filled by active client names.
# KEYS[4] - key with set which is filled by names of clients waiting for critical section to become available.
# ARGV[1] - string client name.
# ARGV[2] - integer maximum semaphore value.
# ARGV[3] - prefix of waiting client queue keys.
use constant EXIT_SCRIPT => <<'EOF';
    if tonumber(redis.call('zrem', KEYS[3], ARGV[1])) == 0 then
        return 0
    end
    local count = tonumber(redis.call('decr', KEYS[1]))
    if count < 0 then
        redis.call('set', KEYS[1], '0')
        return 0
    end
    if count + (tonumber(redis.call('get',KEYS[2]) or '0') > 0 and 1 or 0) + 1 >= tonumber(ARGV[2]) then
        local clients = redis.call('smembers', KEYS[4])
        if table.getn(clients) > 0 then
            for i, client in ipairs(clients) do
                redis.call('rpush', ARGV[3] .. client, '')
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
# ARGV[2] - integer maximum semaphore value.
# ARGV[3] - prefix of waiting client queue keys.
use constant EXIT_READ_SCRIPT => <<'EOF';
    if tonumber(redis.call('zrem', KEYS[3], ARGV[1])) == 0 then
       return 0
    end
    local count = tonumber(redis.call('decr', KEYS[2]))
    if count < 0 then
        redis.call('set', KEYS[2], '0')
        return 0
    end
    if count == 0 and tonumber(redis.call('get',KEYS[1]) or '0') + 1 >= tonumber(ARGV[2]) then
        local clients = redis.call('smembers', KEYS[4])
        if table.getn(clients) > 0 then
            for i, client in ipairs(clients) do
                redis.call('rpush', ARGV[3] .. client, '')
            end
            redis.call('del', KEYS[4])
        end
    end
    return 1
EOF

###############################################################################
# Construct new AnyJob::Semaphore object.
#
# Arguments:
#     redis  - redis connection used to manage semaphore.
#     config - hash with semaphore configuration. Can contain the following fields:
#         key     - string unique semaphore key. Mandatory option.
#         local   - 0/1 flag. If set, this semaphore is local to node and 'node' field becomes mandatory.
#         node    - string current node.
#         count   - maximum semaphore value (i.e. maximum number of enterings inside semaphore). Default: 1.
#         timeout - timeout of seconds before some entering will be automatically cleaned.
# Returns:
#     AnyJob::Semaphore object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{redis})) {
        require Carp;
        Carp::confess('No redis connection provided');
    }

    unless (defined($self->{config})) {
        require Carp;
        Carp::confess('No configuration provided');
    }

    unless (defined($self->{config}->{key}) and $self->{config}->{key} ne '') {
        require Carp;
        Carp::confess('No key provided in configuration');
    }

    if ($self->{config}->{local} and not defined($self->{node})) {
        require Carp;
        Carp::confess('No node provided for local semaphore');
    }

    $self->{count} = $self->{config}->{count} || 1;
    $self->{timeout} = $self->{config}->{timeout} || DEFAULT_CLEAN_TIMEOUT;
    $self->{key} = $self->{config}->{local} ? $self->{node} . ':' . $self->{config}->{key} : $self->{config}->{key};

    $self->{scripts} = {};
    $self->{scripts}->{enter} = $self->{redis}->script('load', ENTER_SCRIPT);
    $self->{scripts}->{enterRead} = $self->{redis}->script('load', ENTER_READ_SCRIPT);
    $self->{scripts}->{exit} = $self->{redis}->script('load', EXIT_SCRIPT);
    $self->{scripts}->{exitRead} = $self->{redis}->script('load', EXIT_READ_SCRIPT);

    return $self;
}

###############################################################################
# Returns:
#     Redis object.
#
sub redis {
    my $self = shift;
    return $self->{redis};
}

###############################################################################
# Returns:
#     String semaphore key.
#
sub key {
    my $self = shift;
    return $self->{key};
}

###############################################################################
# Try to enter inside critical section guarded by this semaphore.
#
# Arguments:
#     client - string unique client name.
# Returns:
#     0/1 flag. If set, semaphore is entered, otherwise - not. In later case you can wait for it to become available
#               using wait queue.
#
sub enter {
    my $self = shift;
    my $client = shift;

    my $key = $self->key;
    my $result = $self->redis->evalsha($self->{scripts}->{enter}, 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:' . $key . ':clients', 'anyjob:sem:' . $key . ':wait', $client, $self->{count},
        time() + $self->{timeout});

    unless ($result) {
        if ($self->cleanTimeoutedClients()) {
            return $self->enter($client);
        }
    }

    return $result;
}

###############################################################################
# Try to enter inside reading critical section guarded by this semaphore.
#
# Arguments:
#     client - string unique reading client name.
# Returns:
#     0/1 flag. If set, semaphore is entered, otherwise - not. In later case you can wait for it to become available
#               using wait queue.
#
sub enterRead {
    my $self = shift;
    my $client = shift;

    my $key = $self->key;
    my $result = $self->redis->evalsha($self->{scripts}->{enterRead}, 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:' . $key . ':clients', 'anyjob:sem:' . $key . ':wait', $client . ':r', $self->{count},
        time() + $self->{timeout});

    unless ($result) {
        if ($self->cleanTimeoutedClients()) {
            return $self->enterRead($client);
        }
    }

    return $result;
}

###############################################################################
# Try to enter inside critical section guarded by this semaphore. If semaphore is unavailable, executioning
# will be blocked for specified timeout value. If specified timeout is undefined or zero, it will block forever until
# semaphore becomes available.
#
# Arguments:
#     client  - string unique client name.
#     timeout - optional integer timeout in seconds.
# Returns:
#     0/1 flag. If set, semaphore is entered, otherwise - not. In later case you can wait for it to become available
#               using wait queue.
#
sub enterBlocked {
    my $self = shift;
    my $client = shift;
    my $timeout = shift;
    $timeout ||= 0;

    while (1) {
        unless ($self->enter($client)) {
            unless ($self->redis->blpop($self->getWaitQueue($client), $timeout)) {
                return 0;
            }
        }
    }

    return 1;
}

###############################################################################
# Try to enter inside reading critical section guarded by this semaphore. If semaphore is unavailable, executioning
# will be blocked for specified timeout value. If specified timeout is undefined or zero, it will block forever until
# semaphore becomes available.
#
# Arguments:
#     client  - string unique reading client name.
#     timeout - optional integer timeout in seconds.
# Returns:
#     0/1 flag. If set, semaphore is entered, otherwise - not. In later case you can wait for it to become available
#               using wait queue.
#
sub enterReadBlocked {
    my $self = shift;
    my $client = shift;
    my $timeout = shift;
    $timeout ||= 0;

    while (1) {
        unless ($self->enterRead($client)) {
            unless ($self->redis->blpop($self->getWaitQueueRead($client), $timeout)) {
                return 0;
            }
        }
    }

    return 1;
}

###############################################################################
# Try to exit from critical section guarded by this semaphore.
#
# Arguments:
#     client - string unique client name.
# Returns:
#     0/1 flag. If set, semaphore is exited, otherwise - not. In later case it probably wasn't entered or was just
#               timeouted before.
#
sub exit {
    my $self = shift;
    my $client = shift;

    my $key = $self->key;
    return $self->redis->evalsha($self->{scripts}->{exit}, 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:' . $key . ':clients', 'anyjob:sem:' . $key . ':wait', $client, $self->{count},
        'anyjob:semq:' . $key . ':');
}

###############################################################################
# Try to exit from reading critical section guarded by this semaphore.
#
# Arguments:
#     client - string unique reading client name.
# Returns:
#     0/1 flag. If set, semaphore is exited, otherwise - not. In later case it probably wasn't entered or was just
#               timeouted before.
#
sub exitRead {
    my $self = shift;
    my $client = shift;

    my $key = $self->key;
    return $self->redis->evalsha($self->{scripts}->{exitRead}, 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:' . $key . ':clients', 'anyjob:sem:' . $key . ':wait', $client . ':r', $self->{count},
        'anyjob:semq:' . $key . ':');
}

###############################################################################
# Clean timeouted entering by clients. Called automatically if semaphore is unavailable.
#
# Returns:
#     integer count of timeouted enterings.
#
sub cleanTimeoutedClients {
    my $self = shift;

    my @clients = $self->redis->zrangebyscore('anyjob:sem:' . $self->key . ':clients', '-inf', time());
    foreach my $client (@clients) {
        if ($client =~ s/:r$//) {
            $self->exitRead($client);
        } else {
            $self->exit($client);
        }
    }
    return scalar(@clients);
}

###############################################################################
# Get redis queue name used by client to receive signal when semaphore becomes available.
#
# Arguments:
#     client - string unique client name.
# Returns:
#     string redis queue name which will receive signal when semaphore becomes available.
#
sub getWaitQueue {
    my $self = shift;
    my $client = shift;
    return 'anyjob:semq:' . $self->key . ':' . $client;
}

###############################################################################
# Get redis queue name used by reading client to receive signal when semaphore becomes available.
#
# Arguments:
#     client - string unique reading client name.
# Returns:
#     string redis queue name which will receive signal when semaphore becomes available.
#
sub getWaitQueueRead {
    my $self = shift;
    my $client = shift;
    return 'anyjob:semq:' . $self->key . ':' . $client . ':r';
}

1;
