package AnyJob::Controller::Observer::Base;

###############################################################################
# Basic observer controller which should be base class for all other observers.
# It does almost nothing, just logs all incoming events.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Observer';

###############################################################################
# This method will be called by parent class for each event to process.
# Log event data here and do nothing more.
#
# Arguments:
#     event - hash with event data.
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    my $config = $self->getObserverConfig();
    unless ($self->preprocessEvent($config, $event)) {
        return;
    }

    $self->logEvent($event);
}

###############################################################################
# Write event data into log.
#
# Arguments:
#     event - hash with event data.
#
sub logEvent {
    my $self = shift;
    my $event = shift;

    $self->debug('Received event \'' . $event->{event} . '\' on node \'' . $event->{node} . '\' by observer \'' .
        $self->name . '\': ' . encode_json($event));
}

1;
