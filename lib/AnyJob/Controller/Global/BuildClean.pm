package AnyJob::Controller::Global::BuildClean;

###############################################################################
# Controller which manages cleaning timeouted builds. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      30.11.2017
# Last update:  14.02.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_DELAY);

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
# Its main task is to collect timeouted builds and clean them.
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $limit = $nodeConfig->{build_clean_limit} || $self->config->limit || DEFAULT_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:builds', '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanBuild($id);
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
    return  $nodeConfig->{build_clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
}

1;
