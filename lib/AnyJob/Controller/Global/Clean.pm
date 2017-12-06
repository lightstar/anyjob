package AnyJob::Controller::Global::Clean;

###############################################################################
# Controller which manages cleaning timeouted jobsets. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      23.10.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_DELAY);
use AnyJob::Constants::Events qw(EVENT_CLEAN_JOBSET);

use base 'AnyJob::Controller::Global';

###############################################################################
# Method called on each iteration of daemon loop.
# Its main task is to collect timeouted jobsets and clean them.
#
sub process {
    my $self = shift;

    if ($self->parent->getActiveJobSetCount() == 0) {
        return;
    }

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $delay = $nodeConfig->{global_clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
    if ($self->isProcessDelayed($delay)) {
        return;
    }

    my $limit = $nodeConfig->{global_clean_limit} || $self->config->limit || DEFAULT_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:jobsets', '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        if (defined(my $jobSet = $self->getJobSet($id))) {
            $self->sendEvent(EVENT_CLEAN_JOBSET, {
                    id    => $id,
                    props => $jobSet->{props},
                    jobs  => $jobSet->{jobs}
                });
        } else {
            $self->error('Cleaned jobset \'' . $id . '\' not found');
        }

        $self->cleanJobSet($id);
    }
}

1;
