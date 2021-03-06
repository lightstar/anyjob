package AnyJob::Controller::Global::BuildClean;

###############################################################################
# Controller which manages cleaning timeouted builds. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      30.11.2017
# Last update:  02.02.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_LIMIT DEFAULT_CLEAN_DELAY);

use base 'AnyJob::Controller::Base';

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
# Returns:
#     integer delay in seconds before the next 'process' method invocation or undef if 'process' method should not be
#     called yet.
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $limit = $nodeConfig->{build_clean_limit} || $self->config->clean_limit || DEFAULT_CLEAN_LIMIT;

    my @ids = $self->redis->zrangebyscore('anyjob:builds', '-inf', time(), 'LIMIT', '0', $limit);
    foreach my $id (@ids) {
        $self->cleanBuild($id);
    }

    return $self->updateProcessDelay($self->delay());
}

###############################################################################
# Remove creator's build data from storage.
#
# Arguments:
#     id - integer build id.
#
sub cleanBuild {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean build \'' . $id . '\'');

    $self->redis->zrem('anyjob:builds', $id);
    $self->redis->del('anyjob:build:' . $id);
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
