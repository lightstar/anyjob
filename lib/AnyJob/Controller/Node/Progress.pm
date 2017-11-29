package AnyJob::Controller::Node::Progress;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_PROGRESS EVENT_REDIRECT EVENT_FINISH);
use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);

use base 'AnyJob::Controller::Node';

sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    my $limit = $nodeConfig->{job_progress_limit} || $self->config->limit || DEFAULT_LIMIT;
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
        } else {
            $self->progressJob($progress);
        }

        $count++;
        last if $count >= $limit;
    }
}

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

sub redirectJob {
    my $self = shift;
    my $progress = shift;

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
