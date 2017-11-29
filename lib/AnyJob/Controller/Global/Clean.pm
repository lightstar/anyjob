package AnyJob::Controller::Global::Clean;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $cleanBefore = $self->config->clean_before || 3600;

    $self->cleanJobSets($limit, $cleanBefore);
    $self->cleanBuilds($limit, $cleanBefore);
}

sub cleanJobSets {
    my $self = shift;
    my $limit = shift;
    my $cleanBefore = shift;

    my %ids = $self->redis->zrangebyscore('anyjob:jobsets', '-inf', time() - $cleanBefore, 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanJobSet($id, $ids{$id});
    }
}

sub cleanBuilds {
    my $self = shift;
    my $limit = shift;
    my $cleanBefore = shift;

    my %ids = $self->redis->zrangebyscore('anyjob:builds', '-inf', time() - $cleanBefore, 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanBuild($id, $ids{$id});
    }
}

1;
