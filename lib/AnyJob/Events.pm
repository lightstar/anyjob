package AnyJob::Events;

use strict;
use warnings;
use utf8;

use Storable qw(dclone);

use base 'Exporter';

our @EXPORT_OK = qw(
    allEvents
    allEventsHash
    isValidEvent
    eventType
    $EVENT_CREATE
    $EVENT_FINISH
    $EVENT_PROGRESS
    $EVENT_REDIRECT
    $EVENT_CREATE_JOBSET
    $EVENT_FINISH_JOBSET
    $EVENT_PROGRESS_JOBSET
    $EVENT_TYPE_JOB
    $EVENT_TYPE_JOBSET
    );

our $EVENT_CREATE = 'create';
our $EVENT_FINISH = 'finish';
our $EVENT_PROGRESS = 'progress';
our $EVENT_REDIRECT = 'redirect';
our $EVENT_CREATE_JOBSET = 'createJobSet';
our $EVENT_FINISH_JOBSET = 'finishJobSet';
our $EVENT_PROGRESS_JOBSET = 'progressJobSet';

our $EVENT_TYPE_JOB = 'job';
our $EVENT_TYPE_JOBSET = 'jobset';

my @EVENTS = (
    {
        event => $EVENT_CREATE,
        type  => $EVENT_TYPE_JOB
    },
    {
        event => $EVENT_FINISH,
        type  => $EVENT_TYPE_JOB
    },
    {
        event => $EVENT_PROGRESS,
        type  => $EVENT_TYPE_JOB
    },
    {
        event => $EVENT_REDIRECT,
        type  => $EVENT_TYPE_JOB
    },
    {
        event => $EVENT_CREATE_JOBSET,
        type  => $EVENT_TYPE_JOBSET
    },
    {
        event => $EVENT_FINISH_JOBSET,
        type  => $EVENT_TYPE_JOBSET
    },
    {
        event => $EVENT_PROGRESS_JOBSET,
        type  => $EVENT_TYPE_JOBSET
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
