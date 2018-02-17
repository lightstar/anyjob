package AnyJob::Controller::Node::Clean;

###############################################################################
# Controller which manages cleaning timeouted jobs on specific node.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  16.02.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_LIMIT DEFAULT_CLEAN_DELAY);
use AnyJob::Constants::Events qw(EVENT_CLEAN);

use base 'AnyJob::Controller::Node';

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

    if ($self->parent->getActiveJobCount() == 0) {
        return undef;
    }

    return $self->calcProcessDelay($self->delay());
}

###############################################################################
# Method called by daemon component on basis of provided delay.
# Its main task is to collect timeouted jobs and clean them.
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $limit = $nodeConfig->{clean_limit} || $self->config->clean_limit || DEFAULT_CLEAN_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:jobs:' . $self->node, '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        if (defined(my $job = $self->getJob($id))) {
            $self->sendEvent(EVENT_CLEAN, {
                    id     => $id,
                    (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
                    type   => $job->{type},
                    params => $job->{params},
                    props  => $job->{props},
                });
        } else {
            $self->error('Cleaned job \'' . $id . '\' not found');
        }

        $self->cleanJob($id);
    }

    $self->updateProcessDelay($self->delay());
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
    return $nodeConfig->{clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
}

1;
