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
    );

my @EVENTS = (
    {
        event => 'create',
        type  => 'job'
    },
    {
        event => 'finish',
        type  => 'job'
    },
    {
        event => 'progress',
        type  => 'job'
    },
    {
        event => 'redirect',
        type  => 'job'
    },
    {
        event => 'createJobSet',
        type  => 'jobset'
    },
    {
        event => 'finishJobSet',
        type  => 'jobset'
    },
    {
        event => 'progressJobSet',
        type  => 'jobset'
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
