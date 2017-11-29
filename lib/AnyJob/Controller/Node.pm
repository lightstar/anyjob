package AnyJob::Controller::Node;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;

use AnyJob::Events qw($EVENT_CREATE);
use AnyJob::States qw($STATE_BEGIN);
use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Base';

our @MODULES = qw(
    Progress
    Clean
    );

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
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

sub createJob {
    my $self = shift;
    my $job = shift;

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    $job->{state} = $STATE_BEGIN;
    $job->{time} = time();

    my $id = $self->nextJobId();
    $self->redis->zadd('anyjob:jobs:' . $self->node, $job->{time}, $id);
    $self->redis->set('anyjob:job:' . $id, encode_json($job));

    $self->debug('Create job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    if (exists($job->{jobset})) {
        my $progress = {
            state  => $STATE_BEGIN,
            node   => $self->node,
            type   => $job->{type},
            params => $job->{params},
            props  => $job->{props}
        };
        $self->sendJobProgressForJobSet($id, $progress, $job->{jobset});
    }

    $self->sendEvent($EVENT_CREATE, {
            id     => $id,
            (exists($job->{jobset}) ? (jobset => $job->{jobset}) : ()),
            type   => $job->{type},
            params => $job->{params},
            props  => $job->{props}
        });

    $self->runJob($job, $id);
}

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
    $self->redis->zadd('anyjob:jobs:' . $self->node, time(), $id);

    $self->debug('Run redirected job \'' . $id . '\' ' .
        (exists($job->{jobset}) ? '(jobset \'' . $job->{jobset} . '\') ' : '') . 'with type \'' . $job->{type} .
        '\', params ' . encode_json($job->{params}) . ' and props ' . encode_json($job->{props}));

    $self->runJob($job, $id);
}

sub runJob {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my ($workDir, $exec, $lib) = $self->config->getJobWorker($job->{type});
    unless (defined($workDir) and defined($exec)) {
        $self->error('Worker or work directory for job with type \'' . $job->{type} .
            '\' are not defined and no global values are set');
        return;
    }

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

sub cleanJob {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    $self->debug('Clean job \'' . $id . '\' last updated at ' . formatDateTime($time));

    $self->redis->zrem('anyjob:jobs:' . $self->node, $id);
    $self->redis->del('anyjob:job:' . $id);
}

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

sub nextJobId {
    my $self = shift;
    return $self->redis->incr('anyjob:job:id');
}

1;
