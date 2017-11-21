package AnyJob::Controller::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Events qw(isValidEvent);

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{parent}) {
        require Carp;
        Carp::confess("No parent provided");
    }

    return $self;
}

sub config {
    my $self = shift;
    return $self->{parent}->config;
}

sub redis {
    my $self = shift;
    return $self->{parent}->redis;
}

sub node {
    my $self = shift;
    return $self->{parent}->node;
}

sub debug {
    my $self = shift;
    my $message = shift;
    $self->{parent}->debug($message);
}

sub error {
    my $self = shift;
    my $message = shift;
    $self->{parent}->error($message);
}

sub getJob {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getJob($id);
}

sub getJobSet {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getJobSet($id);
}

sub sendEvent {
    my $self = shift;
    my $name = shift;
    my $event = shift;

    unless (isValidEvent($name)) {
        $self->error("Unknown event '" . $name . "'");
    }

    $event->{event} = $name;
    $event->{node} = $self->node;
    $event->{time} = time();

    my $encodedData = encode_json($event);

    foreach my $observer (@{$self->config->getObserversForEvent($name)}) {
        $self->redis->rpush("anyjob:observerq:" . $observer, $encodedData);
    }

    my $privateObserver = $self->checkEventProp($event, "observer", "private");
    if (defined($privateObserver)) {
        $self->redis->rpush("anyjob:observerq:private:" . $privateObserver, $encodedData);
    }
}

sub checkEventProp {
    my $self = shift;
    my $event = shift;
    my $prop = shift;
    my $private = shift;

    if (exists($event->{props}) and exists($event->{props}->{$prop})) {
        return $event->{props}->{$prop};
    }

    if (not defined($private) and exists($event->{type})) {
        my $jobConfig = $self->config->getJobConfig($event->{type});
        if ($jobConfig and exists($jobConfig->{$prop})) {
            return $jobConfig->{$prop};
        }
    }

    return undef;
}

sub process {
    my $self = shift;

    require Carp;
    Carp::confess("Need to be implemented in descendant");
}

1;
