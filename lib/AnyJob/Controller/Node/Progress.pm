package AnyJob::Controller::Node::Progress;

###############################################################################
# Controller which manages progressing and finishing jobs on specific node.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  27.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);
use AnyJob::Constants::Events qw(EVENT_PROGRESS EVENT_REDIRECT EVENT_FINISH);

use base 'AnyJob::Controller::Node';

###############################################################################
# Method called on each iteration of daemon loop.
# Its main task is to receive messages from job progress queue and to process them.
# There can be four types of messages.
# 1. 'Finish job' message. Sent by worker component.
# {
#     id => ...,
#     success => 0/1,
#     message => '...'
# }
# 2. 'Redirect job' message. Sent by worker component. Field 'redirect' here contains name of destination node.
# {
#     id => ...,
#     redirect => '...'
# }
# 3. 'Job is redirected' message. Sent by destination node controller after job finished redirecting.
# Field 'redirected' here contains id of redirected job.
# {
#     redirected => ...
# }
# 4. 'Progress job' message. Sent by worker component.
# At least one of fields 'state', 'progress' or 'log' required here.
# Field 'time' is log message time in integer unix timestamp format.
# {
#     id => ...,
#     state => '...',
#     progress => '...',
#     log => { time => ..., message => '...' }
# }
#
sub process {
    my $self = shift;

    if ($self->parent->getActiveJobCount() == 0) {
        return;
    }

    my $nodeConfig = $self->config->getNodeConfig() || {};
    if ($self->isProcessDelayed($nodeConfig->{progress_delay})) {
        return;
    }

    my $limit = $nodeConfig->{progress_limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $progress = $self->redis->lpop('anyjob:progressq:' . $self->node)) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error('Can\'t decode progress: ' . $progress);
        } elsif (exists($progress->{success})) {
            $self->finishJob($progress);
        } elsif (exists($progress->{redirect})) {
            $self->redirectJob($progress);
        } elsif (exists($progress->{redirected})) {
            $self->parent->updateActiveJobCount();
        } else {
            $self->progressJob($progress);
        }

        $count++;
        last if $count >= $limit;
    }
}

###############################################################################
# Progress job.
#
# Arguments:
#     progress - hash with progress data
#               (see 'Progress job' message in 'process' method description about fields it can contain).
#
sub progressJob {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);

    $self->debug('Progress job \'' . $id . '\': ' . encode_json($progress));

    my $jobChanged = 0;

    if (exists($progress->{state})) {
        $job->{state} = $progress->{state};
        $jobChanged = 1;
    }

    if (exists($progress->{progress})) {
        $job->{progress} = $progress->{progress};
        $jobChanged = 1;
    }

    if ($jobChanged) {
        $self->redis->set('anyjob:job:' . $id, encode_json($job));
    }

    if (exists($job->{jobset})) {
        $self->sendJobProgressForJobSet($id, $progress, $job->{jobset});
    }

    $self->sendEvent(EVENT_PROGRESS, {
            id       => $id,
            (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
            type     => $job->{type},
            params   => $job->{params},
            props    => $job->{props},
            progress => $progress
        });
}

###############################################################################
# Redirect job.
#
# Arguments:
#     progress - hash with progress data
#               (see 'Redirect job' message in 'process' method description about fields it can contain).
#
sub redirectJob {
    my $self = shift;
    my $progress = shift;

    unless (defined($progress->{redirect})) {
        return;
    }

    my $id = delete $progress->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    unless ($self->config->isJobSupported($job->{type}, $progress->{redirect})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' .
            $progress->{redirect} . '\'');
        return;
    }

    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);

    $self->debug('Redirect job \'' . $id . '\': ' . encode_json($progress));

    if (exists($job->{jobset})) {
        $self->sendJobProgressForJobSet($id, $progress, $job->{jobset});
    }

    $self->sendEvent(EVENT_REDIRECT, {
            id       => $id,
            (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
            type     => $job->{type},
            params   => $job->{params},
            props    => $job->{props},
            progress => $progress
        });

    my $redirect = {
        id   => $id,
        from => $self->node
    };
    $self->redis->rpush('anyjob:queue:' . $progress->{redirect}, encode_json($redirect));
}

###############################################################################
# Finish job.
#
# Arguments:
#     progress - hash with progress data
#               (see 'Finish job' message in 'process' method description about fields it can contain).
#
sub finishJob {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    $self->debug('Job \'' . $id . '\' ' . ($progress->{success} ? 'successfully finished' : 'finished with error') .
        ': \'' . $progress->{message} . '\'');

    $self->cleanJob($id);

    if ($job->{jobset}) {
        $self->sendJobProgressForJobSet($id, $progress, $job->{jobset});
    }

    $self->sendEvent(EVENT_FINISH, {
            id      => $id,
            (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
            type    => $job->{type},
            params  => $job->{params},
            props   => $job->{props},
            success => $progress->{success},
            message => $progress->{message}
        });
}

1;
