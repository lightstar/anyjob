package AnyJob::Worker::Daemon;

###############################################################################
# Worker component which run as daemon and processes its own job queue.
#
# Author:       LightStar
# Created:      05.03.2018
# Last update:  20.04.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(
    DEFAULT_MAX_DELAY DEFAULT_WORKER_PIDFILE DEFAULT_CHILD_STOP_DELAY DEFAULT_CHILD_STOP_TRIES
    DEFAULT_WORKER_MAX_RUN_TIME
);
use AnyJob::Daemon::Base;

use base 'AnyJob::Worker';

###############################################################################
# Construct new AnyJob::Worker::Daemon object.
#
# Arguments:
#     name - non-empty string with worker name which is also used as queue name.
# Returns:
#     AnyJob::Worker::Daemon object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
    }

    my $workerSection = $self->config->section('worker') || {};
    my $config = $self->getWorkerConfig() || {};
    my $pidfile = $config->{pidfile} || $workerSection->{pidfile} || DEFAULT_WORKER_PIDFILE;
    $pidfile =~ s/\{name\}/$self->{name}/;
    $self->{daemon} = AnyJob::Daemon::Base->new(
        detached       => 0,
        pidfile        => $pidfile,
        delay          => 0,
        childStopDelay => $config->{child_stop_delay} || $workerSection->{child_stop_delay} || DEFAULT_CHILD_STOP_DELAY,
        childStopTries => $config->{child_stop_tries} || $workerSection->{child_stop_tries} || DEFAULT_CHILD_STOP_TRIES,
        logger         => $self->logger,
        processor      => $self
    );

    $self->{delay} = $config->{delay} || $workerSection->{delay} || DEFAULT_MAX_DELAY;
    $self->{count} = $config->{count} || $workerSection->{count} || 1;

    $self->{maxRunTime} = $config->{max_run_time} || $workerSection->{max_run_time} || DEFAULT_WORKER_MAX_RUN_TIME;
    $self->{startTime} = time();

    return $self;
}

###############################################################################
# Prepare and run daemon loop.
#
sub run {
    my $self = shift;

    $self->{daemon}->prepare();

    for (1 .. $self->{count} - 1) {
        if ($self->{daemon}->fork()) {
            last;
        }
    }

    $self->{daemon}->run();

    $self->stop();
}

###############################################################################
# Called by AnyJob::Daemon::Base object before processing.
#
sub init {
    my $self = shift;
}

###############################################################################
# Process worker daemon queue and run job if any.
# Each event in queue is 'Run job' event. It is sent by node controllers and has the following structure.
# {
#     id => ...
# }
# Field 'id' here is integer job's id which needs to be run.
#
sub process {
    my $self = shift;

    my ($queue, $event) = $self->redis->blpop('anyjob:workerq:' . $self->node . ':' . $self->name, $self->{delay});
    if (defined($queue) and defined($event)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error('Can\'t decode event from queue \'' . $queue . '\': ' . $event);
        } else {
            $self->runJob($event->{id});
        }
    }

    if ($self->{daemon}->isParent()) {
        if (time() - $self->{startTime} >= $self->{maxRunTime}) {
            $self->debug('Worker is running too long, stopping now');
            $self->{daemon}->stop();
        } elsif ($self->{daemon}->getChildCount() < $self->{count} - 1) {
            $self->debug('Some childs were stopped, stopping parent now');
            $self->{daemon}->stop();
        }
    }
}

1;
