package AnyJob::Controller::Node::Clean;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_DELAY);
use AnyJob::Constants::Events qw(EVENT_CLEAN);

use base 'AnyJob::Controller::Node';

sub process {
    my $self = shift;

    if ($self->parent->getActiveJobCount() == 0) {
        return;
    }

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $delay = $nodeConfig->{clean_delay} || $self->config->clean_delay || DEFAULT_CLEAN_DELAY;
    if ($self->isProcessDelayed($delay)) {
        return;
    }

    my $limit = $nodeConfig->{clean_limit} || $self->config->limit || DEFAULT_LIMIT;

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
}

1;
