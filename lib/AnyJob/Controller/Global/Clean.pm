package AnyJob::Controller::Global::Clean;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $cleanBefore = $self->config->clean_before || 3600;

    my %ids = $self->redis->zrangebyscore("anyjob:jobset", "-inf", time() - $cleanBefore, "WITHSCORES",
        "LIMIT", 0, $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanJobSet($id, $ids{$id});
    }
}

1;
