package AnyJob::Controller::Global;

###############################################################################
# Controller which manages creating and running jobsets. Only one such controller in whole system must run
# (as it's name, 'global', suggests).
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  28.04.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_CREATE_JOBSET);
use AnyJob::Constants::States qw(STATE_BEGIN);
use AnyJob::Constants::Semaphore;
use AnyJob::Semaphore::Controller;

use base 'AnyJob::Controller::Base';

###############################################################################
# Array with names of additional, also global, controllers which must run along.
#
our @MODULES = qw(
    Progress
    Clean
    BuildClean
    SemaphoreClean
);

###############################################################################
# Construct new AnyJob::Controller::Global object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
# Returns:
#     AnyJob::Controller::Global object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{semaphoreController} = AnyJob::Semaphore::Controller->new(
        parent     => $self->{parent},
        entityType => 'jobset'
    );
    return $self;
}

###############################################################################
# Returns:
#     AnyJob::Semaphore::Controller object.
#
sub semaphoreController {
    my $self = shift;
    return $self->{semaphoreController};
}

###############################################################################
# Method which will be called one time before beginning of processing.
# Used to try to run all jobsets waiting for semaphores.
#
sub init {
    my $self = shift;
    my @ids = $self->redis->smembers('anyjob:jobsets:wait');
    foreach my $id (@ids) {
        $self->tryRunWaitingJobSet($id);
    }
}

###############################################################################
# Get array of all possible event queues.
#
# Returns:
#     array of string queue names.
#
sub getEventQueues {
    my $self = shift;
    return [ 'anyjob:queue' ];
}

###############################################################################
# Get array of semaphore signal queues which needs to be listened by this controller right now.
#
# Returns:
#     array of string queue names.
#
sub getSignalQueues {
    my $self = shift;
    return $self->semaphoreController->getSignalQueues();
}

###############################################################################
# Method called for each received event from new jobsets queue.
# It also can process events with only one job inside redirecting it to queue of the right node (for that
# it must contain string 'node' field).
# There can be two types of events.
# 1. 'Create jobset' event. Sent by creator component. Field 'type' is optional here.
# {
#     type => '...'
#     jobs => [ {
#         type => '...',
#         node => '...',
#         params => { param1 => '...', param2 => '...', ... },
#         props => { prop1 => '...', prop2 => '...', ... }
#     }, ... ]
#     props => { prop1 => '...', prop2 => '...', ... }
# }
# 2. 'Create job' event. Sent by creator component. Obviously provided 'node' field is required here.
# {
#     type => '...',
#     node => '...',
#     params => { param1 => '...', param2 => '...', ... },
#     props => { prop1 => '...', prop2 => '...', ... }
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{node})) {
        my $node = delete $event->{node};
        if (defined($node) and $node ne '') {
            $self->redis->rpush('anyjob:queue:' . $node, encode_json($event));
        } else {
            $self->error('No node in event: ' . encode_json($event));
        }
    } elsif (exists($event->{jobset})) {
        $self->createJobSet($event);
    }
}

###############################################################################
# Method which will be called by daemon component to process signal from one of semaphore queues.
# Used to try to run all jobsets waiting for corresponding semaphore.
#
# Arguments:
#     queue - string queue name from where signal was received.
#
sub processSignal {
    my $self = shift;
    my $queue = shift;

    $self->debug('Received signal from queue \'' . $queue . '\'');

    $self->semaphoreController->processSignal($queue, sub {
        my $id = shift;
        $self->tryRunWaitingJobSet($id);
    });
}

###############################################################################
# Register new jobset and create all jobs contained inside.
#
# Arguments:
#     event - hash with create data.
#
sub createJobSet {
    my $self = shift;
    my $event = shift;

    foreach my $job (@{$event->{jobs}}) {
        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' . $job->{node} .
                '\'. Entire jobset discarded: ' . encode_json($event));
            return;
        }
    }

    my $jobSet = {
        (exists($event->{type}) ? (type => $event->{type}) : ()),
        jobs  => $event->{jobs},
        props => $event->{props},
        state => STATE_BEGIN,
        time  => time()
    };

    foreach my $job (@{$jobSet->{jobs}}) {
        $job->{state} = STATE_BEGIN;
    }

    my $id = $self->getNextJobSetId();
    $self->redis->zadd('anyjob:jobsets', $jobSet->{time} + $self->getJobSetCleanTimeout($jobSet), $id);
    $self->parent->incActiveJobSetCount();

    $self->debug('Create jobset \'' . $id . '\' ' .
        (exists($jobSet->{type}) ? 'with type \'' . $jobSet->{type} . '\'), ' : 'with ') .
        ' props ' . encode_json($jobSet->{props}) . ' and jobs ' . encode_json($jobSet->{jobs}));

    my $isJobSetNotBlocked = 1;
    if (exists($jobSet->{type})) {
        $isJobSetNotBlocked = $self->semaphoreController->processSemaphores(SEMAPHORE_RUN_SEQUENCE, $id, $jobSet,
            $self->config->getJobSetSemaphores($jobSet->{type}));
    }

    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));

    foreach my $job (@{$jobSet->{jobs}}) {
        delete $job->{state};
    }

    unless ($isJobSetNotBlocked) {
        $self->redis->sadd('anyjob:jobsets:wait', $id);
    }

    $self->sendEvent(EVENT_CREATE_JOBSET, {
        id    => $id,
        props => $jobSet->{props},
        jobs  => $jobSet->{jobs}
    });

    if ($isJobSetNotBlocked) {
        foreach my $job (@{$jobSet->{jobs}}) {
            my $node = delete $job->{node};
            $job->{jobset} = $id;
            $self->redis->rpush('anyjob:queue:' . $node, encode_json($job));
        }
    }
}

###############################################################################
# Try to run jobset waiting for some semaphore.
#
# Arguments:
#     id - integer jobset's id.
#
sub tryRunWaitingJobSet {
    my $self = shift;
    my $id = shift;

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    $self->debug('Try run waiting jobset \'' . $id . '\' ' .
        (exists($jobSet->{type}) ? 'with type \'' . $jobSet->{type} . '\'), ' : 'with ') .
        ' props ' . encode_json($jobSet->{props}) . ' and jobs ' . encode_json($jobSet->{jobs}));

    my $isJobSetNotBlocked = 1;
    if (exists($jobSet->{type})) {
        $isJobSetNotBlocked = $self->semaphoreController->processSemaphores(SEMAPHORE_RUN_SEQUENCE, $id, $jobSet,
            $self->config->getJobSetSemaphores($jobSet->{type}));
    }

    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));

    if ($isJobSetNotBlocked) {
        $self->redis->srem('anyjob:jobsets:wait', $id);
        foreach my $job (@{$jobSet->{jobs}}) {
            my $node = delete $job->{node};
            $job->{jobset} = $id;
            $self->redis->rpush('anyjob:queue:' . $node, encode_json($job));
        }
    }
}

###############################################################################
# Remove jobset data from storage.
#
# Arguments:
#     id - integer jobset id.
#
sub cleanJobSet {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean jobset \'' . $id . '\'');

    $self->redis->zrem('anyjob:jobsets', $id);
    $self->redis->del('anyjob:jobset:' . $id);
    $self->parent->decActiveJobSetCount();
}

###############################################################################
# Generate next available id for new jobset.
#
# Returns:
#     integer jobset id.
#
sub getNextJobSetId {
    my $self = shift;
    return $self->redis->incr('anyjob:jobset:id');
}

1;
