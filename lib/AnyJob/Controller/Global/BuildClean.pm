package AnyJob::Controller::Global::BuildClean;

###############################################################################
# Controller which manages cleaning timeouted builds. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      30.11.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_DELAY);

use base 'AnyJob::Controller::Global';

###############################################################################
# Method called on each iteration of daemon loop.
# Its main task is to collect timeouted builds and clean them.
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $delay = $nodeConfig->{build_clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
    if ($self->isProcessDelayed($delay)) {
        return;
    }

    my $limit = $nodeConfig->{build_clean_limit} || $self->config->limit || DEFAULT_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:builds', '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanBuild($id);
    }
}

1;
