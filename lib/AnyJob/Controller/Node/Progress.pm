package AnyJob::Controller::Node::Progress;

###############################################################################
# Controller which manages progressing and finishing jobs on specific node.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  20.04.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_PROGRESS EVENT_REDIRECT EVENT_FINISH);
use AnyJob::Constants::Semaphore;

use base 'AnyJob::Controller::Node';

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
    return [ 'anyjob:progressq:' . $self->node ];
}

###############################################################################
# Get array of event queues which needs to be listened right now.
#
# Returns:
#     array of string queue names.
#
sub getActiveEventQueues {
    my $self = shift;

    if ($self->parent->getActiveJobCount() == 0) {
        return [];
    }

    return $self->getEventQueues();
}

###############################################################################
# Method called for each received event from job progress queue.
# There can be five types of events.
# 1. 'Finish job' event. Sent by worker component. Field 'data' is optional and contain arbitrary hash with
# result data. Often it contains 'text' field with some text data (usually long).
# {
#     id => ...,
#     success => 0/1,
#     message => '...'
#     data => {
#         text => '...'
#     }
# }
# 2. 'Redirect job' event. Sent by worker component. Field 'redirect' here contains name of destination node.
# {
#     id => ...,
#     redirect => '...'
# }
# 3. 'Job is redirected' event. Sent by destination node controller after job finished redirecting.
# Field 'redirected' here contains id of redirected job.
# {
#     redirected => ...
# }
# 4. 'Redo job' event. Sent by worker component.
# {
#     id => ...,
#     redo => 1
# }
# 5. 'Progress job' event. Sent by worker component.
# At least one of fields 'state', 'progress' or 'log' required here.
# Field 'time' is log message time in integer unix timestamp format.
# Fields 'level' and 'tag' are optional and contain integer log level and string log tag accordingly.
# Field 'data' is optional too and contain arbitrary hash with progress data. Often it contains 'text' field
# with some text data (usually long).
# {
#     id => ...,
#     state => '...',
#     progress => '...',
#     log => {
#         time => ...,
#         message => '...',
#         level => ...,
#         tag => '...'
#     },
#     data => {
#         text => '...'
#     }
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{success})) {
        $self->finishJob($event);
    } elsif (exists($event->{redirect})) {
        $self->redirectJob($event);
    } elsif (exists($event->{redirected})) {
        $self->parent->updateActiveJobCount();
    } elsif (exists($event->{redo})) {
        $self->redoJob($event);
    } else {
        $self->progressJob($event);
    }
}

###############################################################################
# Progress job.
#
# Arguments:
#     event - hash with progress data
#             (see 'Progress job' event in 'processEvent' method description about fields it can contain).
#
sub progressJob {
    my $self = shift;
    my $event = shift;

    my $id = delete $event->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);

    $self->debug('Progress job \'' . $id . '\': ' . encode_json($event));

    my $jobChanged = 0;

    if (exists($event->{state})) {
        $job->{state} = $event->{state};
        $jobChanged = 1;
    }

    if (exists($event->{progress})) {
        $job->{progress} = $event->{progress};
        $jobChanged = 1;
    }

    if ($jobChanged) {
        $self->redis->set('anyjob:job:' . $id, encode_json($job));
    }

    $self->sendEvent(EVENT_PROGRESS, {
        id     => $id,
        (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
        type   => $job->{type},
        params => $job->{params},
        props  => $job->{props},
        (exists($event->{state}) ? (state => $event->{state}) : ()),
        (exists($event->{progress}) ? (progress => $event->{progress}) : ()),
        (exists($event->{log}) ? (log => $event->{log}) : ()),
        (exists($event->{data}) ? (data => $event->{data}) : ())
    });

    if (exists($job->{jobset})) {
        $self->sendJobProgressForJobSet($id, $event, $job->{jobset});
    }
}

###############################################################################
# Redirect job.
#
# Arguments:
#     event - hash with progress data
#             (see 'Redirect job' event in 'processEvent' method description about fields it can contain).
#
sub redirectJob {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{redirect})) {
        return;
    }

    my $id = delete $event->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    unless ($self->config->isJobSupported($job->{type}, $event->{redirect})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' .
            $event->{redirect} . '\'');
        return;
    }

    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);

    $self->debug('Redirect job \'' . $id . '\': ' . encode_json($event));

    $self->sendEvent(EVENT_REDIRECT, {
        id       => $id,
        (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
        type     => $job->{type},
        params   => $job->{params},
        props    => $job->{props},
        redirect => $event->{redirect}
    });

    if (exists($job->{jobset})) {
        $self->sendJobProgressForJobSet($id, $event, $job->{jobset});
    }

    my $redirect = {
        id   => $id,
        from => $self->node
    };
    $self->redis->rpush('anyjob:queue:' . $event->{redirect}, encode_json($redirect));
}

###############################################################################
# Redo job.
#
# Arguments:
#     event - hash with redo data
#             (see 'Redo job' event in 'processEvent' method description about fields it can contain).
#
sub redoJob {
    my $self = shift;
    my $event = shift;

    my $id = $event->{id};
    $self->debug('Redo job \'' . $id . '\'');

    my $redo = {
        redo => $id
    };
    $self->redis->rpush('anyjob:queue:' . $self->node, encode_json($redo));
}

###############################################################################
# Finish job.
#
# Arguments:
#     event - hash with progress data
#             (see 'Finish job' event in 'processEvent' method description about fields it can contain).
#
sub finishJob {
    my $self = shift;
    my $event = shift;

    my $id = delete $event->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    delete $job->{semaphores};
    $self->processSemaphores(SEMAPHORE_FINISH_SEQUENCE, $id, $job);

    $self->debug('Job \'' . $id . '\' ' . ($event->{success} ? 'successfully finished' : 'finished with error') .
        ': \'' . $event->{message} . '\'');

    $self->cleanJob($id);

    $self->sendEvent(EVENT_FINISH, {
        id      => $id,
        (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
        type    => $job->{type},
        params  => $job->{params},
        props   => $job->{props},
        success => $event->{success},
        message => $event->{message},
        (exists($event->{data}) ? (data => $event->{data}) : ())
    });

    if ($job->{jobset}) {
        $self->sendJobProgressForJobSet($id, $event, $job->{jobset});
    }
}

1;
