package AnyJob::Semaphore::Instance;

###############################################################################
# Class used to manage one specific distributed semaphore. Semaphore is an entity which is used to guard critical
# sections and can be entered by different clients limited number of times. Clients can be regular (writing) and
# reading ones. Any number of enterings by reading clients are counted as one.
#
# So ordinary usecase of semaphore is such as that: create semaphore object, enter it before critical section and
# exit it after.
#
# If you can't enter semaphore right now, you can use waiting queue to receive signal when semaphore will be freed.
#
# Author:       LightStar
# Created:      27.03.2018
# Last update:  04.04.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_TIMEOUT);

###############################################################################
# Construct new AnyJob::Semaphore::Instance object.
#
# Arguments:
#     engine - AnyJob::Semaphore::Engine object.
#     name   - non-empty string with semaphore name which is also used to construct key name.
#     config - hash with semaphore configuration. Can contain the following fields:
#         local   - 0/1 flag. If set, this semaphore is local to current node.
#         count   - maximum semaphore value (i.e. maximum number of enterings inside semaphore). Default: 1.
#         timeout - timeout of seconds before some entering will be automatically cleaned.
# Returns:
#     AnyJob::Semaphore::Instance object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{engine})) {
        require Carp;
        Carp::confess('No semaphore engine provided');
    }

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
    }

    unless (defined($self->{config})) {
        require Carp;
        Carp::confess('No configuration provided');
    }

    $self->{count} = $self->{config}->{count} || 1;
    $self->{timeout} = $self->{config}->{timeout} || DEFAULT_CLEAN_TIMEOUT;
    $self->{key} = $self->{config}->{local} ?
        $self->engine->config->node . ':' . $self->{name} : $self->{name};

    return $self;
}

###############################################################################
# Returns:
#     Engine object which is usually AnyJob::Semaphore::Engine object.
#
sub engine {
    my $self = shift;
    return $self->{engine};
}

###############################################################################
# Returns:
#     Redis object.
#
sub redis {
    my $self = shift;
    return $self->{engine}->redis;
}


###############################################################################
# Returns:
#     String semaphore name.
#
sub name {
    my $self = shift;
    return $self->{name};
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
    return $self->{engine}->getScriptSha($name);
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
    return $self->redis->evalsha($self->getScriptSha('enter'), 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:clients', 'anyjob:sem:' . $key . ':wait', $key . ':' . $client, $self->{count},
        time() + $self->{timeout});
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
    return $self->redis->evalsha($self->getScriptSha('enterRead'), 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:clients', 'anyjob:sem:' . $key . ':wait', key . ':' . $client . ':r', $self->{count},
        time() + $self->{timeout});
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
    return $self->redis->evalsha($self->getScriptSha('exit'), 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:clients', 'anyjob:sem:' . $key . ':wait', $key . ':' . $client);
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
    return $self->redis->evalsha($self->getScriptSha('exitRead'), 4, 'anyjob:sem:' . $key, 'anyjob:semr:' . $key,
        'anyjob:sem:clients', 'anyjob:sem:' . $key . ':wait', $key . ':' . $client . ':r');
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
