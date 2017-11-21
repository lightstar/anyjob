package AnyJob::Controller::Observer::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Observer';

sub processEvent {
    my $self = shift;
    my $event = shift;

    my $eventJson = encode_json($event);
    utf8::decode($eventJson);
    $self->debug("Received event '" . $event->{event} . "' on node '" . $event->{node} . "' by observer '" .
        $self->name . "': " . $eventJson);
}

1;
