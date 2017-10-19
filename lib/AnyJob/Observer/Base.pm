package AnyJob::Observer::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Observer';

sub processEvent {
    my $self = shift;
    my $event = shift;

    $self->debug("Received event '" . $event->{event} . "' on node '" . $event->{node} . "': " .
        encode_json($event));
}

1;
