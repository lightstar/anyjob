package AnyJob::Observer;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "observer";
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub receiveEvent {
    my $self = shift;
    my $name = shift;

    my $queue = $self->config->getObserverQueue($name);
    unless ($queue) {
        $self->error("No queue for observer '" . $name . "'");
        return undef;
    }

    my $event = $self->redis->lpop("anyjob:observer_queue:" . $queue);
    unless ($event) {
        return undef;
    }

    eval {
        $event = decode_json($event);
    };
    if ($@) {
        $self->error("Can't decode event: " . $event);
        return undef;
    }

    return $event;
}

1;
