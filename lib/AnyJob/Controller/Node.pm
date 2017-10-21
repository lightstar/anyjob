package AnyJob::Controller::Node;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;

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

    $self->debug("Created job '" . $id . "' with type '" . $job->{type} . "' and params " .
        encode_json($job->{params}));

    $self->runJob($job, $id);
}

sub runJob {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my ($worker, $interpreter) = $self->config->getJobWorker($job->{type});
    unless ($worker) {
        $self->error("Worker for job with type '" . $job->{type} . "' is not defined and no global worker is set");
        return;
    }

    my $pid = fork();
    if ($pid != 0) {
        return;
    }

    unless (defined($pid)) {
        $self->error("Can't fork to run job '" . $id . "': " . $!);
        return;
    }

    $self->debug("Run job '" . $id . "' using worker '" . $worker . "'" .
        ($interpreter ? " using interpreter '" . $interpreter . "'" : ""));

    my $node = $self->node;
    my $dir = dirname($worker);
    exec("/bin/sh", "-c", "cd '$dir'; ANYJOB_ID='$id' ANYJOB_NODE='$node' $interpreter $worker");
}

sub cleanJob {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    $self->debug("Clean job '" . $id . "' created at " . formatDateTime($time));

    $self->redis->zrem("anyjob:job", $id);
    $self->redis->del("anyjob:job:" . $id);
    $self->redis->del("anyjob:job:" . $id . ":log");
}

sub nextJobId {
    my $self = shift;
    return $self->redis->incr("anyjob:job:id");
}

1;
