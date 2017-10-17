package AnyJob::Worker;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "worker";
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub getJob {
    my $self = shift;
    my $id = shift;

    my $job = $self->redis->get("anyjob:job:" . $id);
    unless ($job) {
        return undef;
    }

    eval {
        $job = decode_json($job);
    };
    if ($@) {
        return undef;
    }

    return $job;
}

sub sendResult {
    my $self = shift;
    my $id = shift;
    my $result = shift;

    $result->{id} = $id;
    $self->redis->rpush("anyjob:result_queue:" . $self->node, encode_json($result));
}

sub sendProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    $progress->{id} = $id;
    $self->redis->rpush("anyjob:progress_queue:" . $self->node, encode_json($progress));
}

1;
