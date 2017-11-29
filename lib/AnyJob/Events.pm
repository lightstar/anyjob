package AnyJob::Events;

use strict;
use warnings;
use utf8;

use Storable qw(dclone);

use AnyJob::Constants::Events;

use base 'Exporter';

our @EXPORT_OK = qw(
    allEvents
    allEventsHash
    isValidEvent
    eventType
    );

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
    }
);

my %EVENTS_HASH = map {$_->{event} => $_} @EVENTS;

sub allEvents {
    return dclone(\@EVENTS);
}

sub allEventsHash {
    return dclone(\%EVENTS_HASH);
}

sub isValidEvent {
    my $event = shift;
    return exists($EVENTS_HASH{$event}) ? 1 : 0;
}

sub eventType {
    my $event = shift;
    return exists($EVENTS_HASH{$event}) ? $EVENTS_HASH{$event}->{type} : undef;
}

1;
