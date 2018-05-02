package AnyJob::Controller::Global::Clean;

###############################################################################
# Controller which manages cleaning timeouted jobsets. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      23.10.2017
# Last update:  02.05.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_LIMIT DEFAULT_CLEAN_DELAY);
use AnyJob::Constants::Events qw(EVENT_CLEAN_JOBSET);

use base 'AnyJob::Controller::Global';

###############################################################################
# Method which will be called one time before beginning of processing.
#
sub init {
    my $self = shift;
}

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

    if ($self->parent->getActiveJobSetCount() == 0) {
        return undef;
    }

    return $self->calcProcessDelay($self->delay());
}

###############################################################################
# Method called by daemon component on basis of provided delay.
# Its main task is to collect timeouted jobsets and clean them.
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $limit = $nodeConfig->{global_clean_limit} || $self->config->clean_limit || DEFAULT_CLEAN_LIMIT;

    my @ids = $self->redis->zrangebyscore('anyjob:jobsets', '-inf', time(), 'LIMIT', '0', $limit);
    foreach my $id (@ids) {
        if (defined(my $jobSet = $self->getJobSet($id))) {
            $self->sendEvent(EVENT_CLEAN_JOBSET, {
                id    => $id,
                (exists($jobSet->{type}) ? (type => $jobSet->{type}) : ()),
                props => $jobSet->{props},
                jobs  => $jobSet->{jobs}
            });
        } else {
            $self->error('Cleaned jobset \'' . $id . '\' not found');
        }

        $self->cleanJobSet($id);
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
    return $nodeConfig->{global_clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
}

1;
