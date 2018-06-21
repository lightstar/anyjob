package AnyJob::Controller::Node;

###############################################################################
# Controller which manages registering and running jobs on specific node.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  20.06.2018
#

use strict;
use warnings;
use utf8;

use English;
use JSON::XS;
use File::Basename;

use AnyJob::Constants::Events qw(EVENT_CREATE);
use AnyJob::Constants::States qw(STATE_BEGIN);
use AnyJob::Constants::Semaphore;
use AnyJob::Semaphore::Controller;

use base 'AnyJob::Controller::Base';

###############################################################################
# Array with names of additional, also node-binded, controllers which must run along.
# All modules here have implicit prefix 'AnyJob::Controller::Node::'.
#
our @MODULES = qw(
    Progress
    Clean
);

###############################################################################
# Construct new AnyJob::Controller::Node object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
# Returns:
#     AnyJob::Controller::Node object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{semaphoreController} = AnyJob::Semaphore::Controller->new(
        parent     => $self->{parent},
        entityType => 'job'
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
# Used to try to run all jobs waiting for semaphores.
#
sub init {
    my $self = shift;
    my @ids = $self->redis->smembers('anyjob:jobs:' . $self->node . ':wait');
    foreach my $id (@ids) {
        $self->tryRunWaitingJob($id);
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
    return [ 'anyjob:queue:' . $self->node ];
}

###############################################################################
# Get array of event queues which needs to be listened right now.
#
# Returns:
#     array of string queue names.
#
sub getActiveEventQueues {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    if (defined($nodeConfig->{max_jobs}) and $self->parent->getActiveJobCount() >= $nodeConfig->{max_jobs}) {
        return [];
    }

    return $self->getEventQueues();
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
# Method called for each received event from new (or redirected) jobs queue.
# There can be three types of events.
# 1. 'Create job' event. Sent by creator component or by global controller as part of creating jobset.
# Integer 'jobset' field is optional here. If provided, this job is part of jobset.
# {
#     type => '...',
#     jobset => ...,
#     params => { param1 => '...', param2 => '...', ... },
#     props => { prop1 => '...', prop2 => '...', ... }
# }
# 2. 'Finish redirect job' event. Sent by controller of other node.
# Here 'id' is integer job id (as job is already created), and 'from' is the name of source node.
# {
#     id => ...,
#     from => '...'
# }
# 3. 'Finish redo job' event. Sent by progress controller of this node. Here 'redo' field contains
# integer job id.
# {
#     redo => ...
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{from})) {
        $self->finishRedirectJob($event);
    } elsif (exists($event->{redo})) {
        $self->finishRedoJob($event);
    } else {
        $self->createJob($event);
    }
}

###############################################################################
# Method which will be called by daemon component to process signal from one of semaphore queues.
# Used to try to run all jobs waiting for corresponding semaphore.
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
        $self->tryRunWaitingJob($id);
    });
}

###############################################################################
# Create and run new job.
#
# Arguments:
#     event - hash with create data.
#             (see 'Create job' event in 'processEvent' method description about fields it can contain).
#
sub createJob {
    my $self = shift;
    my $event = shift;

    unless ($self->config->isJobSupported($event->{type})) {
        $self->error('Job with type \'' . $event->{type} . '\' is not supported on this node');
        return;
    }

    my $job = {
        type   => $event->{type},
        (exists($event->{jobset}) ? (jobset => $event->{jobset}) : ()),
        state  => STATE_BEGIN,
        time   => time(),
        params => $event->{params} || {},
        props  => $event->{props} || {}
    };

    $job->{state} = STATE_BEGIN;
    $job->{time} = time();

    my $id = $self->getNextJobId();
    $self->redis->zadd('anyjob:jobs:' . $self->node, $job->{time} + $self->getJobCleanTimeout($job), $id);
    $self->parent->incActiveJobCount();

    $self->debug('Create job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    my $isJobNotBlocked = $self->semaphoreController->processSemaphores(SEMAPHORE_RUN_SEQUENCE, $id, $job,
        $self->config->getJobSemaphores($job->{type}));

    $self->redis->set('anyjob:job:' . $id, encode_json($job));

    unless ($isJobNotBlocked) {
        $self->redis->sadd('anyjob:jobs:' . $self->node . ':wait', $id);
    }

    $self->sendEvent(EVENT_CREATE, {
        id     => $id,
        (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
        type   => $job->{type},
        params => $job->{params},
        props  => $job->{props}
    });

    if (exists($job->{jobset})) {
        my $progress = {
            state  => STATE_BEGIN,
            node   => $self->node,
            type   => $job->{type},
            params => $job->{params},
            props  => $job->{props}
        };
        $self->sendJobProgressForJobSet($id, $progress, $job->{jobset});
    }

    if ($isJobNotBlocked) {
        $self->runJob($id, $job);
    }
}

###############################################################################
# Finish redirecting and run redirected job. Here job is removed from source node
# and appropriate notification message is sent to it.
#
# Arguments:
#     event - hash with redirect data. It contains integer 'id' field with job id
#             and string 'from' field with name of source node.
#
sub finishRedirectJob {
    my $self = shift;
    my $event = shift;

    my $id = delete $event->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    $self->redis->zrem('anyjob:jobs:' . $event->{from}, $id);
    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);
    $self->parent->incActiveJobCount();

    $self->redis->rpush('anyjob:progressq:' . $event->{from}, encode_json({
        redirected => $id
    }));

    $self->debug('Run redirected job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    $self->runJob($id, $job);
}

###############################################################################
# Finish redo job operation.
#
# Arguments:
#     event - hash with redo data. It contains integer 'redo' field with job id.
#
sub finishRedoJob {
    my $self = shift;
    my $event = shift;

    my $id = $event->{redo};
    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);

    $self->debug('Run again job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    $self->runJob($id, $job);
}

###############################################################################
# Try to run job waiting for some semaphore.
#
# Arguments:
#     id - integer job's id.
#
sub tryRunWaitingJob {
    my $self = shift;
    my $id = shift;

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    $self->debug('Try run waiting job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    my $isJobNotBlocked = $self->semaphoreController->processSemaphores(SEMAPHORE_RUN_SEQUENCE, $id, $job,
        $self->config->getJobSemaphores($job->{type}));

    $self->redis->set('anyjob:job:' . $id, encode_json($job));

    if ($isJobNotBlocked) {
        $self->redis->srem('anyjob:jobs:' . $self->node . ':wait', $id);
        $self->runJob($id, $job);
    }
}

###############################################################################
# Execute job using either external worker executable or one of running worker daemons.
# Execution using worker executable is asynchronous too because system call 'fork' is used.
#
# Arguments:
#     id  - integer job id.
#     job - hash with job data.
#
sub runJob {
    my $self = shift;
    my $id = shift;
    my $job = shift;

    my $worker = $self->config->getJobWorkerName($job->{type});
    if (defined($worker)) {
        my $workerConfig = $self->config->getWorkerConfig($worker) || {};
        if ($workerConfig->{daemon}) {
            $self->redis->rpush('anyjob:workerq:' . $self->node . ':' . $worker, encode_json({
                id => $id
            }));
            return;
        }
    }

    my ($workDir, $exec, $lib, $user, $group) = $self->config->getJobWorkerOptions($job->{type});
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
        $self->error('Can\'t fork to run job \'' . $id . '\': ' . $!);
        return;
    }

    $EGID = $GID = $gid;
    $EUID = $UID = $uid;

    $self->debug('Run job \'' . $id . '\' executing \'' . $exec . '\' in work directory \'' . $workDir . '\'' .
        ((defined($user) and defined($group)) ? ' under user \'' . $user . '\' and group \'' . $group . '\'' :
            (defined($user) ? ' under user \'' . $user . '\'' :
                (defined($group) ? ' under group \'' . $group . '\'' : ''))) .
        (defined($lib) ? ' including libs in \'' . $lib . '\'' : ''));

    chdir($workDir);

    $ENV{ANYJOB_ID} = $id;
    $ENV{ANYJOB_JOB} = $job->{type};
    if (defined($worker)) {
        $ENV{ANYJOB_WORKER} = $worker;
    }
    if (defined($lib)) {
        $ENV{ANYJOB_WORKER_LIB} = $lib;
    }

    exec($exec);
}

###############################################################################
# Remove job data from storage.
#
# Arguments:
#     id - integer job id.
#
sub cleanJob {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean job \'' . $id . '\'');

    $self->redis->zrem('anyjob:jobs:' . $self->node, $id);
    $self->redis->del('anyjob:job:' . $id);
    $self->parent->decActiveJobCount();
}

###############################################################################
# Send notification to global progress queue about job progress which is part of some jobset.
# In this way jobsets are updated only by global controller upon receiving this notifications.
#
# Arguments:
#     id       - integer job id.
#     progress - hash with job progress data. Details see in AnyJob::Controller::Global::Progress module.
#     jobSetId - integer jobset id.
#
sub sendJobProgressForJobSet {
    my $self = shift;
    my $id = shift;
    my $progress = shift;
    my $jobSetId = shift;

    my $jobSetProgress = {
        id          => $jobSetId,
        job         => $id,
        jobProgress => $progress
    };
    $self->redis->rpush('anyjob:progressq', encode_json($jobSetProgress));
}

###############################################################################
# Generate next available id for new job.
#
# Returns:
#     integer job id.
#
sub getNextJobId {
    my $self = shift;
    return $self->redis->incr('anyjob:job:id');
}

1;
