package AnyJob::Controller::Global::Progress;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;

    while (my $progress = $self->redis->lpop("anyjob:progress_queue")) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error("Can't decode progress: " . $progress);
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
    unless ($jobSet) {
        return;
    }

    my $jobProgress = $progress->{jobProgress};
    my $job = $self->findJobInJobSet($progress->{job}, $jobSet, $jobProgress);

    unless ($job) {
        return;
    }

    $self->redis->zadd("anyjob:jobset", time(), $id);

    $self->debug("Progress jobset '" . $id . "', job's '" . $job->{id} . "' progress: " .
        encode_json($jobProgress));

    if (exists($jobProgress->{success})) {
        $job->{state} = "finished";
        $job->{success} = $jobProgress->{success};
        $job->{message} = $jobProgress->{message};
    } else {
        if (exists($jobProgress->{state})) {
            $job->{state} = $jobProgress->{state};
        }
        if (exists($jobProgress->{progress})) {
            $job->{progress} = $jobProgress->{progress};
        }
    }

    my $jobSetFinished = 0;
    my @finishedJobs = grep {$_->{state} eq "finished"} @{$jobSet->{jobs}};
    if (scalar(@finishedJobs) == scalar(@{$jobSet->{jobs}})) {
        $jobSetFinished = 1;
        if (my $time = $self->redis->zscore("anyjob:jobset", $id)) {
            $self->cleanJobSet($id, $time);
        }
    } else {
        $self->redis->set("anyjob:jobset:" . $id, encode_json($jobSet));
    }

    if ($jobSetFinished) {
        $self->sendEvent("finishJobSet", {
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
    if (exists($jobProgress->{state}) and $jobProgress->{state} eq "begin") {
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
    unless ($jobSet) {
        return;
    }

    $self->redis->zadd("anyjob:jobset", time(), $id);

    $self->debug("Progress jobset '" . $id . "': " . encode_json($progress));

    if (exists($progress->{state})) {
        $jobSet->{state} = $progress->{state};
    }

    if (exists($progress->{progress})) {
        $jobSet->{progress} = $progress->{progress};
    }

    $self->redis->set("anyjob:jobset:" . $id, encode_json($jobSet));

    $self->sendEvent("progressJobSet", {
            id       => $id,
            props    => $jobSet->{props},
            progress => $progress
        });
}

1;
