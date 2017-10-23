package AnyJob::Controller::Global;

use strict;
use warnings;
use utf8;

use JSON::XS;

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
    $self->redis->zadd("anyjob:jobset", time(), $id);
    $self->redis->set("anyjob:jobset:" . $id, encode_json($jobSet));

    foreach my $job (@{$jobSet->{jobs}}) {
        delete $job->{state};
    }

    $self->debug("Create jobset '" . $id . "' with jobs " . encode_json($jobSet->{jobs}));

    $self->sendEvent("createJobSet", {
            id   => $id,
            jobs => $jobSet->{jobs}
        });

    foreach my $job (@{$jobSet->{jobs}}) {
        my $node = delete $job->{node};
        $job->{jobset} = $id;
        $self->redis->rpush("anyjob:queue:" . $node, encode_json($job));
    }
}

sub cleanJobSet {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    $self->debug("Clean jobset '" . $id . "' created at " . formatDateTime($time));

    $self->redis->zrem("anyjob:jobset", $id);
    $self->redis->del("anyjob:jobset:" . $id);
}

sub nextJobSetId {
    my $self = shift;
    return $self->redis->incr("anyjob:jobset:id");
}

1;
