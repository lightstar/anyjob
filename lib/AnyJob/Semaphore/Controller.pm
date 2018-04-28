package AnyJob::Semaphore::Controller;

###############################################################################
# Class used to manage guarding set of arbitrary entities using semaphores.
# Its instance is used inside controllers which run inside daemon.
#
# Author:       LightStar
# Created:      28.04.2018
# Last update:  28.04.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Semaphore;

###############################################################################
# Construct new AnyJob::Semaphore::Controller object.
#
# Arguments:
#     parent     - parent component which is usually instance of AnyJob::Daemon class.
#     entityType - string signifying unique entity type which is guarded by this controller.
#                  By default it is just 'entity'.
# Returns:
#     AnyJob::Semaphore::Controller object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    $self->{entityType} ||= 'entity';
    $self->{waitingEntities} = {};

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually instance of AnyJob::Daemon class.
#
sub parent {
    my $self = shift;
    return $self->{parent};
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
# Get array of semaphore signal queues which needs to be listened.
#
# Returns:
#     array of string queue names.
#
sub getSignalQueues {
    my $self = shift;
    return [ map {'anyjob:semq:' . $_} keys(%{$self->{waitingEntities}}) ];
}

###############################################################################
# Method used to process signal from one of semaphore queues.
#
# Arguments:
#     queue    - string queue name from where signal was received.
#     callback - function which will be called for each entity waiting for corresponding semaphore.
#                It will take entity id as parameter.
#
sub processSignal {
    my $self = shift;
    my $queue = shift;
    my $callback = shift;

    my ($key) = ($queue =~ /^anyjob:semq:(.*)$/o);
    unless (defined($key)) {
        return;
    }

    my $ids = delete $self->{waitingEntities}->{$key};
    unless (defined($ids)) {
        return;
    }

    foreach my $id (@$ids) {
        $callback->($id);
    }
}

###############################################################################
# Execute semaphore sequence for provided entity. Semaphores are entered and exited according to entity
# configuration during process. Only not already entered or exited semaphores are processed.
# This method will use 'semaphores' entity field to store and retrieve information about already entered or exited
# semaphores. This field will be automatically removed when all semaphores are succesfully processed.
#
# Arguments:
#     sequence   - array of hashes with sequence configuration. Each hash must have 'mode' key with one of
#                  predefined semaphore modes for entity and 'action' key with one of predefined semaphore actions for
#                  entity. See AnyJob::Constants::Semaphore for a full list.
#     id         - integer entity id.
#     entity     - hash with entity data.
#     semaphores - hash with entity semaphores configuration.
# Returns:
#     0/1 flag. If set, all semaphores are successfully entered or exited, otherwise some are blocked and entity must
#               wait.
#
sub processSemaphores {
    my $self = shift;
    my $sequence = shift;
    my $id = shift;
    my $entity = shift;
    my $semaphores = shift;

    foreach my $step (grep {exists($semaphores->{$_->{mode}})} @$sequence) {
        foreach my $semaphore (@{$semaphores->{$step->{mode}}}) {
            my ($name, $client, $key) = $self->prepareSemaphore($id, $entity, $semaphore, $step->{mode});
            unless (defined($name)) {
                next;
            }

            {
                no strict 'refs';
                my $method = $step->{action} . 'Semaphore';
                unless ($self->$method($id, $name, $client)) {
                    return 0;
                }
            }

            $entity->{semaphores} ||= {};
            $entity->{semaphores}->{$key} = 1;
        }
    }

    delete $entity->{semaphores};

    return 1;
}

###############################################################################
# Prepare specific semaphore for given entity.
#
# Arguments:
#     id         - integer entity id.
#     entity     - hash with entity data.
#     semaphore  - hash with semaphore data from entity configuration.
#     mode       - string mode which is one of predefined semaphore modes for entity.
# Returns:
#     string semaphore name.
#     string semaphore client name.
#     string key identifying this semaphore entering by entity.
#
sub prepareSemaphore {
    my $self = shift;
    my $id = shift;
    my $entity = shift;
    my $semaphore = shift;
    my $mode = shift;

    my $name = $semaphore->{name};
    my $client = $self->{entityType};
    my $key = $name;
    if (exists($semaphore->{client}) and $semaphore->{client} ne $client) {
        $client = $semaphore->{client};
        $key .= ':' . $client;
    }

    if (exists($entity->{semaphores}) and $entity->{semaphores}->{$key}) {
        return undef;
    }

    my $clientMode = $semaphore->{cmode} || SEMAPHORE_DEFAULT_CLIENT_MODES()->{$mode};
    if ($clientMode eq SEMAPHORE_CLIENT_MODE_ENTITY) {
        $client .= ':' . $id;
    } elsif ($clientMode eq SEMAPHORE_CLIENT_MODE_JOBSET and exists($entity->{jobset})) {
        $client .= ':' . $entity->{jobset};
    }

    return ($name, $client, $key);
}

###############################################################################
# Enter into specific semaphore for given entity.
#
# Arguments:
#     id     - integer entity id.
#     name   - string semaphore name.
#     client - string semaphore client name.
# Returns:
#     0/1 flag. If set, semaphore was successfully entered, otherwise it is blocked and entity must wait.
#
sub enterSemaphore {
    my $self = shift;
    my $id = shift;
    my $name = shift;
    my $client = shift;

    my $semaphoreInstance = $self->parent->getSemaphore($name);
    if ($semaphoreInstance->enter($client)) {
        $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' entered into semaphore \'' . $name . '\'' .
            ' (client: \'' . $client . '\')');
        return 1;
    }

    $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' is waiting for semaphore \'' . $name . '\'' .
        ' (client: \'' . $client . '\')');

    push @{$self->{waitingEntities}->{$semaphoreInstance->key() . ':' . $client}}, $id;

    return 0;
}

###############################################################################
# Enter into specific semaphore for given entity in 'read' mode.
#
# Arguments:
#     id     - integer entity id.
#     name   - string semaphore name.
#     client - string semaphore client name.
# Returns:
#     0/1 flag. If set, semaphore was successfully entered, otherwise it is blocked and entity must wait.
#
sub enterReadSemaphore {
    my $self = shift;
    my $id = shift;
    my $name = shift;
    my $client = shift;

    my $semaphoreInstance = $self->parent->getSemaphore($name);
    if ($semaphoreInstance->enterRead($client)) {
        $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' entered into semaphore \'' . $name . '\'' .
            ' (client: \'' . $client . '\')' . ' in \'read\' mode');
        return 1;
    }

    $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' is waiting for semaphore \'' . $name . '\'' .
        ' (client: \'' . $client . '\')' . ' in \'read\' mode');

    push @{$self->{waitingEntities}->{$semaphoreInstance->key() . ':' . $client . ':r'}}, $id;

    return 0;
}

###############################################################################
# Exit from specific semaphore for given entity.
#
# Arguments:
#     id     - integer entity id.
#     name   - string semaphore name.
#     client - string semaphore client name.
# Returns:
#     0/1 flag. Always 1 here because semaphore exiting can't be blocked.
#
sub exitSemaphore {
    my $self = shift;
    my $id = shift;
    my $name = shift;
    my $client = shift;

    $self->parent->getSemaphore($name)->exit($client);

    $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' exited from semaphore \'' . $name . '\'' .
        ' (client: \'' . $client . '\')');

    return 1;
}

###############################################################################
# Exit from specific semaphore for given job in 'read' mode.
#
# Arguments:
#     id     - integer job's id.
#     name   - string semaphore name.
#     client - string semaphore client name.
# Returns:
#     0/1 flag. Always 1 here because semaphore exiting can't be blocked.
#
sub exitReadSemaphore {
    my $self = shift;
    my $id = shift;
    my $name = shift;
    my $client = shift;

    $self->parent->getSemaphore($name)->exitRead($client);

    $self->debug(ucfirst($self->{entityType}) . ' \'' . $id . '\' exited from semaphore \'' . $name . '\'' .
        ' (client: \'' . $client . '\')' . ' in \'read\' mode');

    return 1;
}

1;
