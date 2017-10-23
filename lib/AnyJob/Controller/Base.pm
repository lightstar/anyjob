package AnyJob::Controller::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;

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
    my $event = shift;
    my $data = shift;

    $data->{event} = $event;
    $data->{node} = $self->node;

    my $encodedData = encode_json($data);
    foreach my $queue (@{$self->config->getObserverQueuesForEvent($event)}) {
        $self->redis->rpush("anyjob:observer_queue:" . $queue, $encodedData);
    }
}

sub process {
    my $self = shift;

    require Carp;
    Carp::confess("Need to be implemented in descendant");
}

1;
