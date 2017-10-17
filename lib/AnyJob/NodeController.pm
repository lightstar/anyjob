package AnyJob::NodeController;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;

use base 'AnyJob::BaseController';

sub processQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $job = $self->redis->lpop("anyjob:queue:" . $self->node)) {
        eval {
            $job = decode_json($job);
        };
        if ($@) {
            $self->error("Can't decode job: $job");
        } else {
            $self->createJob($job);
        }

        $count++;
        last if $count >= $limit;
    }
}

sub processResultQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $result = $self->redis->lpop("anyjob:result_queue:" . $self->node)) {
        eval {
            $result = decode_json($result);
        };
        if ($@) {
            $self->error("Can't decode result: " . $result);
        } else {
            $self->finishJob($result);
        }

        $count++;
        last if $count >= $limit;
    }
}

sub processProgressQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $progress = $self->redis->lpop("anyjob:progress_queue:" . $self->node)) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error("Can't decode progress: " . $progress);
        } else {
            $self->debug("Got progress: " . encode_json($progress));
        }

        $count++;
        last if $count >= $limit;
    }
}

sub createJob {
    my $self = shift;
    my $job = shift;

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error("Job with type '" . $job->{type} . "' is not supported on this node");
        return;
    }

    $job->{state} = "begin";

    my $id = $self->nextJobId();
    $self->redis->zadd("anyjob:job", time(), $id);
    $self->redis->set("anyjob:job:" . $id, encode_json($job));

    $self->sendEvent("create", {
            id     => $id,
            type   => $job->{type},
            params => $job->{params}
        });

    $self->debug("Created job '" . $id . "' with type '" . $job->{type} . "' and params " . encode_json($job->{params}));

    $self->runJob($job, $id);
}

sub runJob {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my $worker = $self->config->getJobWorker($job->{type});
    unless ($worker) {
        $self->error("Worker for job with type '" . $job->{type} . "' is not defined and no global worker is set");
        return;
    }

    my $pid = fork();
    if ($pid != 0) {
        return;
    }

    unless (defined($pid)) {
        $self->error("Can't fork to run job '" . $id . "'");
        return;
    }

    $self->debug("Run job '" . $id . "' using worker '" . $worker . "'");

    my $dir = dirname($worker);
    exec("/bin/sh", "-c", "cd $dir; ANYJOB_ID=$id $worker >/dev/null 2>&1");
}

sub finishJob {
    my $self = shift;
    my $result = shift;

    my $id = $result->{id};

    my $job = $self->redis->get("anyjob:job:" . $id);
    eval {
        $job = decode_json($job);
    };
    if ($@) {
        $self->error("Can't decode job '" . $id . "'");
        return;
    }

    $self->redis->zrem("anyjob:job", $id);
    $self->redis->del("anyjob:job:" . $id);

    $self->sendEvent("finish", {
            id      => $id,
            type    => $job->{type},
            params  => $job->{params},
            success => $result->{success},
            message => $result->{message}
        });

    $self->debug("Job '" . $id . "' " . ($result->{success} ? "successfully finished" : "finished with error") . ": '" . $result->{message} . "'");
}

sub nextJobId {
    my $self = shift;
    return $self->redis->incr("anyjob:job:id");
}

1;
