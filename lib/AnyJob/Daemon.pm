package AnyJob::Daemon;

use strict;
use warnings;
use utf8;

use AnyJob::Daemon::Base;
use AnyJob::Controller::Factory;
use AnyJob::Constants::Defaults qw(DEFAULT_DELAY DEFAULT_PIDFILE);

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'daemon';
    my $self = $class->SUPER::new(%args);

    if ($self->node eq '') {
        require Carp;
        Carp::confess('No node');
    }

    my $config = $self->config->section('daemon') || {};
    $self->{daemon} = AnyJob::Daemon::Base->new(
        detached  => $config->{detached} || 0,
        pidfile   => $config->{pidfile} || DEFAULT_PIDFILE,
        delay     => $config->{delay} || DEFAULT_DELAY,
        logger    => $self->logger,
        processor => $self
    );

    $self->{controllers} = AnyJob::Controller::Factory->new(parent => $self)->collect();

    return $self;
}

sub run {
    my $self = shift;
    $self->{daemon}->run();
}

sub process {
    my $self = shift;

    foreach my $controller (@{$self->{controllers}}) {
        $controller->process();
    }
}

sub initActiveJobCount {
    my $self = shift;

    unless (exists($self->{activeJobCount})) {
        $self->updateActiveJobCount();
    }
}

sub getActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    return $self->{activeJobCount};
}

sub updateActiveJobCount {
    my $self = shift;
    $self->{activeJobCount} = $self->redis->zcard('anyjob:jobs:' . $self->node);
}

sub incActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    $self->{activeJobCount}++;
}

sub decActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    $self->{activeJobCount}--;
}

sub initActiveJobSetCount {
    my $self = shift;

    unless (exists($self->{activeJobSetCount})) {
        $self->updateActiveJobSetCount();
    }
}

sub getActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    return $self->{activeJobSetCount};
}

sub updateActiveJobSetCount {
    my $self = shift;
    $self->{activeJobSetCount} = $self->redis->zcard('anyjob:jobsets');
}

sub incActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    $self->{activeJobSetCount}++;
}

sub decActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    $self->{activeJobSetCount}--;
}

1;
