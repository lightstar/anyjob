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
    my ($self, $message) = @_;
    $self->{parent}->debug($message);
}

sub error {
    my ($self, $message) = @_;
    $self->{parent}->error($message);
}

sub getJob {
    my ($self, $id) = @_;
    return $self->{parent}->getJob($id);
}

sub sendEvent {
    my ($self, $event, $data) = @_;

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
