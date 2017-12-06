package AnyJob::Controller::Global::Progress;

###############################################################################
# Controller which manages progressing and finishing jobsets. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);
use AnyJob::Constants::Events qw(EVENT_PROGRESS_JOBSET EVENT_FINISH_JOBSET);
use AnyJob::Constants::States qw(STATE_BEGIN STATE_FINISHED);

use base 'AnyJob::Controller::Global';

###############################################################################
# Method called on each iteration of daemon loop.
# Its main task is to receive messages from jobset progress queue and to process them.
# There can be two types of messages.
# 1. 'Progress jobset' message. Sent by worker component.
# At least one of fields 'state' or 'progress' required here.
# {
#     id => ...,
#     state => '...',
#     progress => '...',
# }
# 2. 'Progress job in jobset' message. Sent by node-binded controller which creates and progresses jobs.
# Here 'id' field is integer jobset id, and 'job' field - integer job id.
# At least one of fields 'state', 'progress', 'log', 'redirect' or 'success' should be in 'jobProgress' hash.
# Field 'message' should be here only along with 'success' field.
# Fields 'type', 'node', 'params' and 'props' should be in 'jobProgress' hash only when job is first created and its
# id is yet unknown.
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
#         log => { time => ..., message => '...' },
#         redirect => '...',
#         success => 0/1,
#         message => '...'
#     }
# }
#
sub process {
    my $self = shift;

    if ($self->parent->getActiveJobSetCount() == 0) {
        return;
    }

    my $nodeConfig = $self->config->getNodeConfig() || {};
    if ($self->isProcessDelayed($nodeConfig->{global_progress_delay})) {
        return;
    }

    my $limit = $nodeConfig->{global_progress_limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $progress = $self->redis->lpop('anyjob:progressq')) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error('Can\'t decode progress: ' . $progress);
        } elsif (exists($progress->{job})) {
            $self->progressJobInJobSet($progress);
        } else {
            $self->progressJobSet($progress);
        }

        $count++;
        last if $count >= $limit;
    }
}

###############################################################################
# Progress job inside jobset. Finish and clean jobset if all jobs in it are finished.
#
# Arguments:
#     progress - hash with progress data.
#                (see 'Progress job in jobset' message in 'process' method description about fields it can contain).
#
sub progressJobInJobSet {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    my $jobProgress = $progress->{jobProgress};
    my $job = $self->findJobInJobSet($progress->{job}, $jobSet, $jobProgress);
    unless (defined($job)) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time() + $self->getJobSetCleanTimeout($jobSet), $id);

    $self->debug('Progress jobset \'' . $id . '\', job\'s \'' . $job->{id} . '\' progress: ' .
        encode_json($jobProgress));

    unless (exists($job->{id})) {
        $job->{id} = $progress->{job};
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
        $self->cleanJobSet($id);
    } else {
        $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));
    }

    if ($jobSetFinished) {
        $self->debug('Jobset \'' . $id . '\' finished');

        $self->sendEvent(EVENT_FINISH_JOBSET, {
                id    => $id,
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
#                   (see 'Progress job in jobset' message in 'process' method description about fields it can contain).
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
#     progress - hash with progress data.
#                (see 'Progress jobset' message in 'process' method description about fields it can contain).
#
sub progressJobSet {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time() + $self->getJobSetCleanTimeout($jobSet), $id);

    $self->debug('Progress jobset \'' . $id . '\': ' . encode_json($progress));

    if (exists($progress->{state})) {
        $jobSet->{state} = $progress->{state};
    }

    if (exists($progress->{progress})) {
        $jobSet->{progress} = $progress->{progress};
    }

    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));

    $self->sendEvent(EVENT_PROGRESS_JOBSET, {
            id       => $id,
            props    => $jobSet->{props},
            progress => $progress
        });
}

1;
