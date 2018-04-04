package AnyJob::Daemon;

###############################################################################
# Daemon component subclassed from AnyJob::Base, which primary task is to run different configured controllers
# (under 'Controller' package path), which are depended on current node.
# This class also manages starting/stopping worker daemons and some shared state variables:
# active job count (for regular nodes) and active jobset count (for global node).
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  04.04.2018
#

use strict;
use warnings;
use utf8;

use English;
use Time::HiRes qw(usleep);
use JSON::XS;

use AnyJob::Constants::Defaults qw(
    DEFAULT_MIN_DELAY DEFAULT_MAX_DELAY DEFAULT_DAEMON_PIDFILE DEFAULT_CHILD_STOP_DELAY DEFAULT_CHILD_STOP_TRIES
    DEFAULT_WORKER_STOP_DELAY DEFAULT_WORKER_STOP_TRIES DEFAULT_WORKER_PIDFILE DEFAULT_WORKER_CHECK_DELAY
);
use AnyJob::Utils qw(readInt isProcessRunning);
use AnyJob::Daemon::Base;
use AnyJob::Controller::Factory;
use AnyJob::Semaphore::Engine;

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
        detached       => defined($config->{detached}) ? ($config->{detached} ? 1 : 0) : 1,
        pidfile        => $config->{pidfile} || DEFAULT_DAEMON_PIDFILE,
        delay          => 0,
        childStopDelay => $config->{child_stop_delay} || DEFAULT_CHILD_STOP_DELAY,
        childStopTries => $config->{child_stop_tries} || DEFAULT_CHILD_STOP_TRIES,
        logger         => $self->logger,
        processor      => $self
    );

    $self->{controllers} = AnyJob::Controller::Factory->new(parent => $self)->collect();

    $self->{controllersByEventQueue} = {};
    foreach my $controller (@{$self->{controllers}}) {
        foreach my $eventQueue (@{$controller->getEventQueues()}) {
            $self->{controllersByEventQueue}->{$eventQueue} = $controller;
        }
    }

    $self->{minDelay} = $config->{min_delay} || DEFAULT_MIN_DELAY;
    $self->{maxDelay} = $config->{max_delay} || DEFAULT_MAX_DELAY;

    $self->{workerCheckDelay} = $config->{worker_check_delay} || DEFAULT_WORKER_CHECK_DELAY;
    $self->{workerCheckLastTime} = time();

    $self->{semaphoreEngine} = AnyJob::Semaphore::Engine->new(parent => $self);

    return $self;
}

###############################################################################
# Prepare and run daemon loop.
#
sub run {
    my $self = shift;

    $self->{daemon}->prepare();
    $self->runWorkers();
    $self->isolateControllers();
    $self->{daemon}->run();
    if ($self->{daemon}->isParent()) {
        $self->stopWorkers();
    }
}

###############################################################################
# Run all worker daemons as separate processes.
#
sub runWorkers {
    my $self = shift;

    foreach my $worker (@{$self->config->getNodeWorkers()}) {
        $self->runWorker($worker);
    }
}

###############################################################################
# Run specified worker daemon as separate process.
#
# Arguments:
#     worker - string worker name.
#
sub runWorker {
    my $self = shift;
    my $worker = shift;

    my ($workDir, $exec, $lib, $user, $group) = $self->config->getWorkerDaemonOptions($worker);
    unless (defined($workDir)) {
        return;
    }

    my ($uid, $gid) = (0, 0);

    if (defined($user)) {
        unless (defined($uid = getpwnam($user))) {
            $self->error('Wrong user name: \'' . $user . '\'');
            return;
        }
    }

    if (defined($group)) {
        unless (defined($gid = getgrnam($group))) {
            $self->error('Wrong group name: \'' . $group . '\'');
            return;
        }
    }

    my $pid = fork();
    if ($pid != 0) {
        return;
    }

    unless (defined($pid)) {
        $self->error('Can\'t fork to run worker \'' . $worker . '\': ' . $!);
        return;
    }

    $EGID = $GID = $gid;
    $EUID = $UID = $uid;

    $self->debug('Run worker \'' . $worker . '\' in work directory \'' . $workDir . '\'' .
        ((defined($user) and defined($group)) ? ' under user \'' . $user . '\' and group \'' . $group . '\'' :
            (defined($user) ? ' under user \'' . $user . '\'' :
                (defined($group) ? ' under group \'' . $group . '\'' : ''))) .
        (defined($lib) ? ' including libs in \'' . $lib . '\'' : ''));

    chdir($workDir);

    $ENV{ANYJOB_WORKER} = $worker;
    if (defined($lib)) {
        $ENV{ANYJOB_WORKER_LIB} = $lib;
    }

    exec($exec);
}

###############################################################################
# Check running worker daemon processes. If some of them are not running then rerun them.
#
sub checkWorkers {
    my $self = shift;

    my $workerSection = $self->config->section('worker') || {};
    foreach my $worker (@{$self->config->getNodeWorkers()}) {
        my $config = $self->config->getWorkerConfig($worker) || {};

        my $pidfile = $config->{pidfile} || $workerSection->{pidfile} || DEFAULT_WORKER_PIDFILE;
        $pidfile =~ s/\{name\}/$worker/;
        my $pid = readInt($pidfile);
        unless ($pid and isProcessRunning($pid)) {
            $self->runWorker($worker);
        }
    }
}

###############################################################################
# Stop all worker daemon processes.
#
sub stopWorkers {
    my $self = shift;

    my $workerSection = $self->config->section('worker') || {};
    foreach my $worker (@{$self->config->getNodeWorkers()}) {
        my $config = $self->config->getWorkerConfig($worker) || {};

        my $delay = $config->{stop_delay} || $workerSection->{stop_delay} || DEFAULT_WORKER_STOP_DELAY;
        my $maxTries = $config->{stop_tries} || $workerSection->{stop_tries} || DEFAULT_WORKER_STOP_TRIES;

        my $pidfile = $config->{pidfile} || $workerSection->{pidfile} || DEFAULT_WORKER_PIDFILE;
        $pidfile =~ s/\{name\}/$worker/;
        if (my $pid = readInt($pidfile)) {
            my $try = 0;
            while (isProcessRunning($pid)) {
                if ($try >= $maxTries) {
                    $self->error('Can\'t stop worker \'' . $worker . '\'');
                    last;
                }
                kill TERM => $pid;
                usleep($delay * 1000000);
                $try++;
            }
        }
    }
}

###############################################################################
# Fork for each isolated controller to run it in separate process.
#
sub isolateControllers {
    my $self = shift;

    my $controllers = [];
    foreach my $controller (@{$self->{controllers}}) {
        if ($controller->isIsolated()) {
            if ($self->{daemon}->fork()) {
                $self->{controllers} = [ $controller ];
                return;
            }
        } else {
            push @$controllers, $controller;
        }
    }
    $self->{controllers} = $controllers;
}

###############################################################################
# Process all daemon controllers.
# Controllers 'process' method is called here on basis of delay specified by controllers themselves.
# Queues are queried and controllers 'processEvent' or 'processSignal' methods are called for each received message.
#
sub process {
    my $self = shift;

    my @queues;
    my $minDelay = $self->{maxDelay};

    foreach my $controller (@{$self->{controllers}}) {
        my $delay = $controller->getProcessDelay();

        if (defined($delay) and $delay == 0) {
            $delay = $controller->process();
        }

        if (defined($delay)) {
            if ($delay < $self->{minDelay}) {
                $delay = $self->{minDelay};
            }
            if ($delay < $minDelay) {
                $minDelay = $delay;
            }
        }

        push @queues, @{$controller->getActiveEventQueues()};
    }

    if (scalar(@queues) > 0) {
        my ($queue, $message) = $self->redis->blpop(@queues, $minDelay);
        if (defined($queue) and defined($message)) {
            if ($message eq '') {
                $self->{controllersByEventQueue}->{$queue}->processSignal($queue);
            } else {
                my $event;
                eval {
                    $event = decode_json($message);
                };
                if ($@) {
                    $self->error('Can\'t decode event from queue \'' . $queue . '\': ' . $message);
                } else {
                    $self->{controllersByEventQueue}->{$queue}->processEvent($event);
                }
            }
        }
    } else {
        sleep($minDelay);
    }

    if ($self->{daemon}->isParent() and time() - $self->{workerCheckLastTime} >= $self->{workerCheckDelay}) {
        $self->checkWorkers();
        $self->{workerCheckLastTime} = time();
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

###############################################################################
# Returns:
#     Semaphores engine which is usually AnyJob::Semaphore::Engine object.
#
sub getSemaphoreEngine {
    my $self = shift;
    return $self->{semaphoreEngine};
}

###############################################################################
# Get semaphore object instance with specified name.
#
# Arguments:
#     name - string semaphore name.
# Returns:
#     AnyJob::Semaphore::Instance object.
#
sub getSemaphore {
    my $self = shift;
    my $name = shift;
    return $self->{semaphoreEngine}->getSemaphore($name);
}

1;
