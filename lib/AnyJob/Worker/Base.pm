package AnyJob::Worker::Base;

use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{worker})) {
        require Carp;
        Carp::confess("No worker provided");
    }

    unless ($self->{id}) {
        require Carp;
        Carp::confess("No job id provided");
    }

    unless (defined($self->{job})) {
        require Carp;
        Carp::confess("No job provided");
    }

    return $self;
}

sub id {
    my $self = shift;
    return $self->{id};
}

sub job {
    my $self = shift;
    return $self->{job};
}

sub worker {
    my $self = shift;
    return $self->{worker};
}

sub jobset {
    my $self = shift;
    return $self->{job}->{jobset};
}

sub type {
    my $self = shift;
    return $self->{job}->{type};
}

sub params {
    my $self = shift;
    return $self->{job}->{params};
}

sub param {
    my $self = shift;
    my $name = shift;
    return $self->{job}->{params}->{$name};
}

sub props {
    my $self = shift;
    return $self->{job}->{props};
}

sub prop {
    my $self = shift;
    my $name = shift;
    return $self->{job}->{props}->{$name};
}

sub node {
    my $self = shift;
    return $self->{worker}->node;
}

sub debug {
    my $self = shift;
    my $message = shift;
    $self->{worker}->debug($message);
}

sub error {
    my $self = shift;
    my $message = shift;
    $self->{worker}->error($message);
}

sub sendProgress {
    my $self = shift;
    my $progress = shift;
    $self->{worker}->sendProgress($self->id, $progress);
}

sub sendState {
    my $self = shift;
    my $state = shift;
    $self->{worker}->sendState($self->id, $state)
}

sub sendLog {
    my $self = shift;
    my $message = shift;
    $self->{worker}->sendLog($self->id, $message);
}

sub sendRedirect {
    my $self = shift;
    my $node = shift;
    $self->{worker}->sendRedirect($self->id, $node);
}

sub sendSuccess {
    my $self = shift;
    my $message = shift;
    $self->{worker}->sendSuccess($self->id, $message);
}

sub sendFailure {
    my $self = shift;
    my $message = shift;
    $self->{worker}->sendFailure($self->id, $message);
}

sub sendJobSetProgress {
    my $self = shift;
    my $progress = shift;
    if (defined($self->jobset)) {
        $self->{worker}->sendJobSetProgress($self->jobset, $progress);
    }
}

sub sendJobSetState {
    my $self = shift;
    my $state = shift;
    if (defined($self->jobset)) {
        $self->{worker}->sendJobSetState($state);
    }
}

sub run {
    my $self = shift;

    require Carp;
    Carp::confess("Need to be implemented in descendant");
}

1;
