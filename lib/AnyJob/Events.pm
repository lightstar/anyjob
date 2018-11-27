package AnyJob::Events;

###############################################################################
# Utility functions related to events.
#
# Author:       LightStar
# Created:      27.10.2017
# Last update:  27.11.2018
#

use strict;
use warnings;
use utf8;

use Storable qw(dclone);

use AnyJob::Constants::Events;

use base 'Exporter';

our @EXPORT_OK = qw(
    getAllEvents
    getAllEventsHash
    isValidEvent
    getEventType
    );

###############################################################################
# All valid events with their names and types.
#
my @EVENTS = (
    {
        event => EVENT_CREATE,
        type  => EVENT_TYPE_JOB
    },
    {
        event => EVENT_FINISH,
        type  => EVENT_TYPE_JOB
    },
    {
        event => EVENT_PROGRESS,
        type  => EVENT_TYPE_JOB
    },
    {
        event => EVENT_REDIRECT,
        type  => EVENT_TYPE_JOB
    },
    {
        event => EVENT_CLEAN,
        type  => EVENT_TYPE_JOB
    },
    {
        event => EVENT_CREATE_JOBSET,
        type  => EVENT_TYPE_JOBSET
    },
    {
        event => EVENT_FINISH_JOBSET,
        type  => EVENT_TYPE_JOBSET
    },
    {
        event => EVENT_PROGRESS_JOBSET,
        type  => EVENT_TYPE_JOBSET
    },
    {
        event => EVENT_CLEAN_JOBSET,
        type  => EVENT_TYPE_JOBSET
    },
    {
        event => EVENT_DELAYED_WORKS,
        type  => EVENT_TYPE_DELAYED_WORK
    }
);

###############################################################################
# All valid events with their names and types structured as hash by even name.
#
my %EVENTS_HASH = map {$_->{event} => $_} @EVENTS;

###############################################################################
# Get all valid events with there types as array.
# Array is cloned so can be changed by external functions without any harm.
#
# Returns:
#     array with events info.
#
sub getAllEvents {
    return dclone(\@EVENTS);
}

###############################################################################
# Get all valid events with there types as hash by event name.
# Hash is cloned so can be changed by external functions without any harm.
#
# Returns:
#     hash with events info by event name.
#
sub getAllEventsHash {
    return dclone(\%EVENTS_HASH);
}

###############################################################################
# Check if given event name is valid.
#
# Arguments:
#     event - string event name
# Returns:
#     0/1 flag determining if event name is valid.
#
sub isValidEvent {
    my $event = shift;
    return exists($EVENTS_HASH{$event}) ? 1 : 0;
}

###############################################################################
# Get event type by it's name or undef if provided name is not valid.
#
# Arguments:
#     event - string event name
# Returns:
#     string event type or undef if provided name is not valid.
#
sub getEventType {
    my $event = shift;
    return exists($EVENTS_HASH{$event}) ? $EVENTS_HASH{$event}->{type} : undef;
}

1;
