package AnyJob::Controller::Node;

###############################################################################
# Controller which manages registering and running jobs on specific node.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  05.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);
use AnyJob::Constants::Events qw(EVENT_CREATE);
use AnyJob::Constants::States qw(STATE_BEGIN);

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
# Method called on each iteration of daemon loop.
# Its main task is to receive messages from new (or redirected) jobs queue and to process them.
# There can be two types of messages.
# 1. 'Create job' message. Sent by creator component or by global controller as part of creating jobset.
# Integer 'jobset' field is optional here. If provided, this job is part of jobset.
# {
#     type => '...',
#     jobset => ...,
#     params => { param1 => '...', param2 => '...', ... },
#     props => { prop1 => '...', prop2 => '...', ... }
# }
# 2. 'Run redirected job' message. Sent by controller of other node.
# Here 'id' is integer job id (as job is already created), and 'from' is the name of source node.
# {
#     id => ...,
#     from => '...'
# }
#
sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    if ($self->isProcessDelayed($nodeConfig->{create_delay})) {
        return;
    }

    if (defined($nodeConfig->{max_jobs}) and $self->parent->getActiveJobCount() >= $nodeConfig->{max_jobs}) {
        return;
    }

    my $limit = $nodeConfig->{create_limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $job = $self->redis->lpop('anyjob:queue:' . $self->node)) {
        eval {
            $job = decode_json($job);
        };
        if ($@) {
            $self->error('Can\'t decode job: ' . $job);
        } elsif ($job->{from}) {
            $self->runRedirectedJob($job);
        } else {
            $self->createJob($job);
        }

        $count++;
        last if $count >= $limit;
    }
}

###############################################################################
# Create and run new job.
#
# Arguments:
#     job - hash with job data.
#
sub createJob {
    my $self = shift;
    my $job = shift;

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    $job->{state} = STATE_BEGIN;
    $job->{time} = time();

    my $id = $self->getNextJobId();
    $self->redis->zadd('anyjob:jobs:' . $self->node, $job->{time} + $self->getJobCleanTimeout($job), $id);
    $self->redis->set('anyjob:job:' . $id, encode_json($job));
    $self->parent->incActiveJobCount();

    $self->debug('Create job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

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

    $self->sendEvent(EVENT_CREATE, {
            id     => $id,
            (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
            type   => $job->{type},
            params => $job->{params},
            props  => $job->{props}
        });

    $self->runJob($job, $id);
}

###############################################################################
# Finish redirecting and run redirected job. Here job is removed from source node
# and appropriate notification message is sent to it.
#
# Arguments:
#     redirect - hash with redirect data. It contains integer 'id' field with job id
#                and string 'from' field with name of source node.
#
sub runRedirectedJob {
    my $self = shift;
    my $redirect = shift;

    my $id = delete $redirect->{id};

    my $job = $self->getJob($id);
    unless (defined($job)) {
        return;
    }

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    $self->redis->zrem('anyjob:jobs:' . $redirect->{from}, $id);
    $self->redis->zadd('anyjob:jobs:' . $self->node, time() + $self->getJobCleanTimeout($job), $id);
    $self->parent->incActiveJobCount();

    $self->redis->rpush('anyjob:progressq:' . $redirect->{from}, encode_json({
            redirected => $id
        }));

    $self->debug('Run redirected job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    $self->runJob($job, $id);
}

###############################################################################
# Execute job using external worker. That execution is asynchronous because system call to 'fork' is used.
#
# Arguments:
#     job - hash with job data.
#     id  - integer job id.
#
sub runJob {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my ($workDir, $exec, $lib) = $self->config->getJobWorker($job->{type});

    my $pid = fork();
    if ($pid != 0) {
        return;
    }

    unless (defined($pid)) {
        $self->error('Can\'t fork to run job \'' . $id . '\': ' . $!);
        return;
    }

    $self->debug('Run job \'' . $id . '\' executing \'' . $exec . '\' in work directory \'' . $workDir . '\'' .
        (defined($lib) ? ' including libs in \'' . $lib . '\'' : ''));

    exec('/bin/sh', '-c',
        'cd \'' . $workDir . '\'; ' .
            (defined($lib) ? 'ANYJOB_WORKER_LIB=\'' . $lib . '\' ' : '') . 'ANYJOB_ID=\'' . $id . '\' ' . $exec);
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
