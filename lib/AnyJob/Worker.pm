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

sub sendProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    $progress->{id} = $id;
    $self->redis->rpush("anyjob:progress_queue:" . $self->node, encode_json($progress));
}

1;
