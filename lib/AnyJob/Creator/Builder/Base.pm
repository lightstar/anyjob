package AnyJob::Creator::Builder::Base;

use strict;
use warnings;
use utf8;

use AnyJob::DateTime qw(formatDateTime);

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
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

sub cleanBuild {
    my $self = shift;
    my $id = shift;

    if (my $time = $self->redis->zscore('anyjob:builds', $id)) {
        $self->debug('Clean build \'' . $id . '\' last updated at ' . formatDateTime($time));
        $self->redis->zrem('anyjob:builds', $id);
        $self->redis->del('anyjob:build:' . $id);
    }
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

sub update {
    my $self = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

1;
