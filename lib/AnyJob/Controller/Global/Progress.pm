package AnyJob::Controller::Global::Progress;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Events qw($EVENT_PROGRESS_JOBSET $EVENT_FINISH_JOBSET);
use AnyJob::States qw($STATE_BEGIN $STATE_FINISHED);

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
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

    unless ($job) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time(), $id);

    $self->debug('Progress jobset \'' . $id . '\', job\'s \'' . $job->{id} . '\' progress: ' .
        encode_json($jobProgress));

    if (exists($jobProgress->{success})) {
        $job->{state} = $STATE_FINISHED;
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
    my @finishedJobs = grep {$_->{state} eq $STATE_FINISHED} @{$jobSet->{jobs}};
    if (scalar(@finishedJobs) == scalar(@{$jobSet->{jobs}})) {
        $jobSetFinished = 1;
        if (my $time = $self->redis->zscore('anyjob:jobsets', $id)) {
            $self->cleanJobSet($id, $time);
        }
    } else {
        $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));
    }

    if ($jobSetFinished) {
        $self->sendEvent($EVENT_FINISH_JOBSET, {
                id    => $id,
                props => $jobSet->{props},
                jobs  => $jobSet->{jobs}
            });
    }
}

sub findJobInJobSet {
    my $self = shift;
    my $jobId = shift;
    my $jobSet = shift;
    my $jobProgress = shift;

    my $job;
    if (exists($jobProgress->{state}) and $jobProgress->{state} eq $STATE_BEGIN) {
        ($job) = grep {
            $_->{node} eq $jobProgress->{node} and
                $_->{type} eq $jobProgress->{type} and not exists($_->{id})
        } @{$jobSet->{jobs}};

        if ($job) {
            $job->{id} = $jobId;
        }
    } else {
        ($job) = grep {$_->{id} == $jobId} @{$jobSet->{jobs}};
    }

    return $job;
}

sub progressJobSet {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $jobSet = $self->getJobSet($id);
    unless (defined($jobSet)) {
        return;
    }

    $self->redis->zadd('anyjob:jobsets', time(), $id);

    $self->debug('Progress jobset \'' . $id . '\': ' . encode_json($progress));

    if (exists($progress->{state})) {
        $jobSet->{state} = $progress->{state};
    }

    if (exists($progress->{progress})) {
        $jobSet->{progress} = $progress->{progress};
    }

    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));

    $self->sendEvent($EVENT_PROGRESS_JOBSET, {
            id       => $id,
            props    => $jobSet->{props},
            progress => $progress
        });
}

1;
