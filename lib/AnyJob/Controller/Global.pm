package AnyJob::Controller::Global;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Base';

sub process {
    my $self = shift;
    $self->processQueue();
    $self->processProgressQueue();
    $self->processResultQueue();
}

sub processQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $job = $self->redis->lpop("anyjob:queue")) {
        eval {
            $job = decode_json($job);
        };
        if ($@) {
            $self->error("Can't decode job: " . $job);
        } elsif ($job->{node}) {
            my $node = delete $job->{node};
            $self->redis->rpush("anyjob:queue:" . $node, encode_json($job));
        } elsif ($job->{jobset}) {
            $self->createJobSet($job);
        }

        $count++;
        last if $count >= $limit;
    }
}

sub processResultQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $result = $self->redis->lpop("anyjob:result_queue")) {
        eval {
            $result = decode_json($result);
        };
        if ($@) {
            $self->error("Can't decode result: " . $result);
        } else {
            $self->debug("Got jobset result: " . encode_json($result));
        }

        $count++;
        last if $count >= $limit;
    }
}

sub processProgressQueue {
    my $self = shift;

    my $limit = $self->config->limit;
    my $count = 0;

    while (my $progress = $self->redis->lpop("anyjob:progress_queue")) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error("Can't decode progress: " . $progress);
        } else {
            $self->debug("Got jobset progress: " . encode_json($progress));
        }

        $count++;
        last if $count >= $limit;
    }
}

sub createJobSet {
    my $self = shift;
    my $jobSet = shift;

    foreach my $job (@{$jobSet->{jobs}}) {
        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error("Job with type '" . $job->{type} . "' is not supported on node '" . $job->{node} .
                "'. Entire jobset discarded: " . encode_json($jobSet));
            return;
        }
    }

    $jobSet->{state} = "begin";
    foreach my $job (@{$jobSet->{jobs}}) {
        $job->{state} = "begin";
    }

    my $id = $self->nextJobSetId();
    $self->redis->zadd("anyjob:jobsets", time(), $id);
    $self->redis->set("anyjob:jobset:" . $id, encode_json($jobSet));

    foreach my $job (@{$jobSet->{jobs}}) {
        delete $job->{state};
        my $node = delete $job->{node};
        $job->{jobset_id} = $id;
        $self->redis->rpush("anyjob:queue:" . $node, encode_json($job));
    }
}

sub nextJobSetId {
    my $self = shift;
    return $self->redis->incr("anyjob:jobset:id");
}

1;
