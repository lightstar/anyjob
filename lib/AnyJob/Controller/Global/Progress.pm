package AnyJob::Controller::Global::Progress;

###############################################################################
# Controller which manages progressing and finishing jobsets. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  02.05.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_PROGRESS_JOBSET EVENT_FINISH_JOBSET);
use AnyJob::Constants::States qw(STATE_BEGIN STATE_FINISHED);
use AnyJob::Constants::Semaphore;

use base 'AnyJob::Controller::Global';

###############################################################################
# Method which will be called one time before beginning of processing.
#
sub init {
    my $self = shift;
}

###############################################################################
# Get array of all possible event queues.
#
# Returns:
#     array of string queue names.
#
sub getEventQueues {
    my $self = shift;
    return [ 'anyjob:progressq' ];
}

###############################################################################
# Get array of event queues which needs to be listened right now.
#
# Returns:
#     array of string queue names.
#
sub getActiveEventQueues {
    my $self = shift;

    if ($self->parent->getActiveJobSetCount() == 0) {
        return [];
    }

    return $self->getEventQueues();
}

###############################################################################
# Method called for each received event from jobset progress queue.
# There can be two types of events.
# 1. 'Progress jobset' event. Sent by worker component.
# At least one of fields 'state' or 'progress' required here.
# Field 'data' is optional and contain arbitrary hash with progress data. Often it contains 'text' field
# with some text data (usually long).
# {
#     id => ...,
#     state => '...',
#     progress => '...',
#     data => {
#         text => '...'
#     }
# }
# 2. 'Progress job in jobset' event. Sent by node-binded controller which creates and progresses jobs.
# Here 'id' field is integer jobset id, and 'job' field - integer job id.
# At least one of fields 'state', 'progress', 'log', 'redirect' or 'success' should be in 'jobProgress' hash.
# Field 'message' should be here only along with 'success' field.
# Fields 'type', 'node', 'params' and 'props' should be in 'jobProgress' hash only when job is first created and its
# id is yet unknown.
# Field 'data' is optional and contain arbitrary hash with result or progress data. Often it contains 'text' field
# with some text data (usually long).
# {
#     id => ...
#     job => ...,
#     jobProgress => {
#         type => '...',
#         node => '...',
#         params => { ... },
#         props => { ... },
#         state => '...',
#         progress => '...',
#         log => { time => ..., message => '...', level => ..., tag => '...' },
#         redirect => '...',
#         success => 0/1,
#         message => '...',
#         data => { text => '...' }
#     }
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{job})) {
        $self->progressJobInJobSet($event);
    } else {
        $self->progressJobSet($event);
    }
}

###############################################################################
# Progress job inside jobset. Finish and clean jobset if all jobs in it are finished.
#
# Arguments:
#     event - hash with progress data.
#             (see 'Progress job in jobset' event in 'processEvent' method description about fields it can contain).
#
sub progressJobInJobSet {
    my $self = shift;
    my $event = shift;

    my $id = delete $event->{id};

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    my $jobProgress = $event->{jobProgress};
    my $job = $self->findJobInJobSet($event->{job}, $jobSet, $jobProgress);
    unless (defined($job)) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time() + $self->getJobSetCleanTimeout($jobSet), $id);

    $self->debug('Progress jobset \'' . $id . '\', job\'s \'' . $event->{job} . '\' progress: ' .
        encode_json($jobProgress));

    unless (exists($job->{id})) {
        $job->{id} = $event->{job};
    }

    if (exists($jobProgress->{success})) {
        $job->{state} = STATE_FINISHED;
        $job->{success} = $jobProgress->{success};
        $job->{message} = $jobProgress->{message};
    } else {
        if (exists($jobProgress->{redirect})) {
            $job->{node} = $jobProgress->{redirect};
        }
        if (exists($jobProgress->{state})) {
            $job->{state} = $jobProgress->{state};
        }
        if (exists($jobProgress->{progress})) {
            $job->{progress} = $jobProgress->{progress};
        }
    }

    my $jobSetFinished = 0;
    my @finishedJobs = grep {$_->{state} eq STATE_FINISHED} @{$jobSet->{jobs}};
    if (scalar(@finishedJobs) == scalar(@{$jobSet->{jobs}})) {
        $jobSetFinished = 1;

        if (exists($jobSet->{type})) {
            $self->semaphoreController->processSemaphores(SEMAPHORE_FINISH_SEQUENCE, $id, $jobSet,
                $self->config->getJobSetSemaphores($jobSet->{type}));
        }

        $self->debug('Jobset \'' . $id . '\' finished');
        $self->cleanJobSet($id);
    } else {
        $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));
    }

    if ($jobSetFinished) {
        $self->sendEvent(EVENT_FINISH_JOBSET, {
            id    => $id,
            (exists($jobSet->{type}) ? (type => $jobSet->{type}) : ()),
            props => $jobSet->{props},
            jobs  => $jobSet->{jobs}
        });
    }
}

###############################################################################
# Find job in jobset's job array by job id or by its type and node if id is yet unknown.
#
# Arguments:
#     jobId       - integer job id.
#     jobSet      - hash with jobset data.
#     jobProgress - hash with job progress data.
#                   (see 'Progress job in jobset' event in 'processEvent' method description about fields it can
#                   contain).
# Returns:
#     hash with job data or undef if job not found.
#
sub findJobInJobSet {
    my $self = shift;
    my $jobId = shift;
    my $jobSet = shift;
    my $jobProgress = shift;

    my $job;
    if (exists($jobProgress->{state}) and $jobProgress->{state} eq STATE_BEGIN) {
        ($job) = grep {
            $_->{node} eq $jobProgress->{node} and
                $_->{type} eq $jobProgress->{type} and not exists($_->{id})
        } @{$jobSet->{jobs}};
    } else {
        ($job) = grep {$_->{id} == $jobId} @{$jobSet->{jobs}};
    }

    return $job;
}

###############################################################################
# Progress jobset.
#
# Arguments:
#     event - hash with progress data.
#             (see 'Progress jobset' event in 'processEvent' method description about fields it can contain).
#
sub progressJobSet {
    my $self = shift;
    my $event = shift;

    my $id = delete $event->{id};

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time() + $self->getJobSetCleanTimeout($jobSet), $id);

    $self->debug('Progress jobset \'' . $id . '\': ' . encode_json($event));

    if (exists($event->{state})) {
        $jobSet->{state} = $event->{state};
    }

    if (exists($event->{progress})) {
        $jobSet->{progress} = $event->{progress};
    }

    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));

    $self->sendEvent(EVENT_PROGRESS_JOBSET, {
        id    => $id,
        (exists($jobSet->{type}) ? (type => $jobSet->{type}) : ()),
        props => $jobSet->{props},
        (exists($event->{state}) ? (state => $event->{state}) : ()),
        (exists($event->{progress}) ? (progress => $event->{progress}) : ()),
        (exists($event->{data}) ? (data => $event->{data}) : ())
    });
}

1;
