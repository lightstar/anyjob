package AnyJob::Daemon;

###############################################################################
# Daemon component subclassed from AnyJob::Base, which primary task is to run different configured controllers
# (under 'Controller' package path), which are depended on current node.
# This class also manages active job count (for regular nodes) and active jobset count (for global node).
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  14.02.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_DELAY DEFAULT_PIDFILE);
use AnyJob::Daemon::Base;
use AnyJob::Controller::Factory;

use base 'AnyJob::Base';

###############################################################################
# Construct new AnyJob::Daemon object.
#
# Returns:
#     AnyJob::Daemon object.
#
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
        detached  => defined($config->{detached}) ? ($config->{detached} ? 1 : 0) : 1,
        pidfile   => $config->{pidfile} || DEFAULT_PIDFILE,
        delay     => 0,
        logger    => $self->logger,
        processor => $self
    );

    $self->{controllers} = AnyJob::Controller::Factory->new(parent => $self)->collect();

    $self->{controllersByEventQueue} = {};
    foreach my $controller (@{$self->{controllers}}) {
        foreach my $eventQueue (@{$controller->getEventQueues()}) {
            $self->{controllersByEventQueue}->{$eventQueue} = $controller;
        }
    }

    $self->{maxDelay} = $config->{max_delay} || DEFAULT_DELAY;

    return $self;
}

###############################################################################
# Run daemon loop.
#
sub run {
    my $self = shift;
    $self->{daemon}->run();
}

###############################################################################
# Process all daemon controllers.
# Controllers 'process' method is called here on basis of delay specified by controllers themselves.
# Queues are queried and controllers 'processEvent' method is called for each event.
#
sub process {
    my $self = shift;

    my @queues;
    my $minDelay = $self->{maxDelay};
    foreach my $controller (@{$self->{controllers}}) {
        my $delay = $controller->getProcessDelay();

        if (defined($delay) and $delay == 0) {
            $delay = $controller->process();
            if (defined($delay) and $delay == 0) {
                $delay = DEFAULT_DELAY;
            }
        }

        if (defined($delay) and (not defined($minDelay) or $delay < $minDelay)) {
            $minDelay = $delay;
        }

        push @queues, @{$controller->getActiveEventQueues()};
    }

    if (scalar(@queues) > 0) {
        my ($queue, $event) = $self->redis->blpop(@queues, $minDelay);
        if (defined($queue) and defined($event)) {
            eval {
                $event = decode_json($event);
            };
            if ($@) {
                $self->error('Can\'t decode event from queue \'' . $queue . '\': ' . $event);
            } else {
                $self->{controllersByEventQueue}->{$queue}->processEvent($event);
            }
        }
    } else {
        sleep($minDelay);
    }
}

###############################################################################
# Load active job count on current node if needed.
#
sub initActiveJobCount {
    my $self = shift;

    unless (exists($self->{activeJobCount})) {
        $self->updateActiveJobCount();
    }
}

###############################################################################
# Get active job count on current node.
#
# Returns:
#     integer active job count.
#
sub getActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    return $self->{activeJobCount};
}

###############################################################################
# Update active job count on current node.
#
sub updateActiveJobCount {
    my $self = shift;
    $self->{activeJobCount} = $self->redis->zcard('anyjob:jobs:' . $self->node);
}

###############################################################################
# Increase by one active job count on current node.
#
sub incActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    $self->{activeJobCount}++;
}

###############################################################################
# Decrease by one active job count on current node.
#
sub decActiveJobCount {
    my $self = shift;
    $self->initActiveJobCount();
    $self->{activeJobCount}--;
}

###############################################################################
# Load active jobset count if needed.
#
sub initActiveJobSetCount {
    my $self = shift;

    unless (exists($self->{activeJobSetCount})) {
        $self->updateActiveJobSetCount();
    }
}

###############################################################################
# Get active jobset count.
#
# Returns:
#     integer active jobset count.
#
sub getActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    return $self->{activeJobSetCount};
}

###############################################################################
# Update active jobset count.
#
sub updateActiveJobSetCount {
    my $self = shift;
    $self->{activeJobSetCount} = $self->redis->zcard('anyjob:jobsets');
}

###############################################################################
# Increase by one active jobset count.
#
sub incActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    $self->{activeJobSetCount}++;
}

###############################################################################
# Decrease by one active jobset count.
#
sub decActiveJobSetCount {
    my $self = shift;
    $self->initActiveJobSetCount();
    $self->{activeJobSetCount}--;
}

1;
