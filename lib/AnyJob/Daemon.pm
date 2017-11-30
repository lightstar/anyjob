package AnyJob::Daemon;

use strict;
use warnings;
use utf8;

use AnyJob::Daemon::Base;
use AnyJob::Controller::Factory;
use AnyJob::Constants::Defaults qw(DEFAULT_DELAY DEFAULT_UPDATE_COUNTS_DELAY DEFAULT_PIDFILE);

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
        detached => $config->{detached} || 0,
        pidfile  => $config->{pidfile} || DEFAULT_PIDFILE,
        delay    => $config->{delay} || DEFAULT_DELAY,
        logger   => $self->logger,
        process  => sub {$self->process()}
    );

    my $nodeConfig = $self->config->getNodeConfig() || {};
    $self->{updateCountsDelay} = $nodeConfig->{update_counts_delay} || $config->{update_counts_delay} ||
        DEFAULT_UPDATE_COUNTS_DELAY;

    $self->{controllers} = AnyJob::Controller::Factory->new(parent => $self)->collect();

    return $self;
}

sub run {
    my $self = shift;
    $self->{daemon}->run();
}

sub process {
    my $self = shift;

    $self->updateCounts();

    foreach my $controller (@{$self->{controllers}}) {
        $controller->process();
    }
}

sub updateCounts {
    my $self = shift;

    my $time = time();
    if ($time - ($self->{lastUpdateTime} || 0) > $self->{updateCountsDelay}) {
        if (($self->{activeJobCount} || 0) > 0) {
            $self->updateActiveJobCount();
        }
        if (($self->{activeJobSetCount} || 0) > 0) {
            $self->updateActiveJobSetCount();
        }
        $self->{lastUpdateTime} = $time;
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
