package AnyJob::Creator::Builder::Base;

use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{parent}) {
        require Carp;
        Carp::confess("No parent provided");
    }

    unless ($self->{name}) {
        require Carp;
        Carp::confess("No name provided");
    }

    return $self;
}

sub parent {
    my $self = shift;
    return $self->{parent};
}

sub config {
    my $self = shift;
    return $self->{parent}->config;
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub redis {
    my $self = shift;
    return $self->{parent}->redis;
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

sub getBuild {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getObject('anyjob:build:' . $id);
}

sub nextBuildId {
    my $self = shift;
    return $self->{parent}->redis->incr('anyjob:build:id');
}

sub build {
    my $self = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

1;
