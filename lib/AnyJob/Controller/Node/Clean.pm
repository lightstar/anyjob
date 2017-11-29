package AnyJob::Controller::Node::Clean;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Node';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $cleanBefore = $self->config->clean_before || 3600;

    my %ids = $self->redis->zrangebyscore('anyjob:jobs:' . $self->node, '-inf', time() - $cleanBefore, 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanJob($id, $ids{$id});
    }
}

1;
