package AnyJob::Controller::Global::SemaphoreClean;

###############################################################################
# Controller which manages cleaning timeouted enterings by semaphore clients.
# Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      05.04.2018
# Last update:  20.04.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_LIMIT DEFAULT_CLEAN_DELAY);

use base 'AnyJob::Controller::Global';

###############################################################################
# Get array of all possible event queues.
#
# Returns:
#     array of string queue names.
#
sub getEventQueues {
    my $self = shift;
    return [];
}

###############################################################################
# Get array of event queues which needs to be listened right now.
#
# Returns:
#     array of string queue names.
#
sub getActiveEventQueues {
    my $self = shift;
    return [];
}

###############################################################################
# Get delay before next 'process' method invocation.
#
# Arguments:
#     integer delay in seconds or undef if 'process' method should not be called at all.
#
sub getProcessDelay {
    my $self = shift;
    return $self->calcProcessDelay($self->delay());
}

###############################################################################
# Method called by daemon component on basis of provided delay.
# Its main task is to clean timeouted enterings by semaphore clients.
#
sub process {
    my $self = shift;

    my $count = $self->parent->getSemaphoreEngine()->cleanTimeoutedClients();
    if ($count > 0) {
        $self->debug('Cleaned ' . $count . ' semaphore enterings');
    }

    return $self->updateProcessDelay($self->delay());
}

###############################################################################
# Get delay between 'process' method invocations.
#
# Arguments:
#     integer delay in seconds.
#
sub delay {
    my $self = shift;
    my $nodeConfig = $self->config->getNodeConfig() || {};
    return $nodeConfig->{semaphore_clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
}

1;
