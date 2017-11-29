package AnyJob::Controller::Observer::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Observer';

sub processEvent {
    my $self = shift;
    my $event = shift;

    my $config = $self->observerConfig();
    unless ($self->preprocessEvent($config, $event)) {
        return;
    }

    $self->logEvent($event);
}

sub logEvent {
    my $self = shift;
    my $event = shift;

    $self->debug('Received event \'' . $event->{event} . '\' on node \'' . $event->{node} . '\' by observer \'' .
        $self->name . '\': ' . encode_json($event));
}

1;
