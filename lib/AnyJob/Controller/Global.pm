package AnyJob::Controller::Global;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_CREATE_JOBSET);
use AnyJob::Constants::States qw(STATE_BEGIN);
use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);

use base 'AnyJob::Controller::Base';

our @MODULES = qw(
    Progress
    Clean
    BuildClean
    );

sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    if ($self->isProcessDelayed($nodeConfig->{global_create_delay})) {
        return;
    }

    my $limit = $nodeConfig->{global_create_limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $job = $self->redis->lpop('anyjob:queue')) {
        eval {
            $job = decode_json($job);
        };
        if ($@) {
            $self->error('Can\'t decode job: ' . $job);
        } elsif (exists($job->{node})) {
            my $node = delete $job->{node};
            $self->redis->rpush('anyjob:queue:' . $node, encode_json($job));
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
            $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' . $job->{node} .
                '\'. Entire jobset discarded: ' . encode_json($jobSet));
            return;
        }
    }

    $jobSet->{state} = STATE_BEGIN;
    $jobSet->{time} = time();
    foreach my $job (@{$jobSet->{jobs}}) {
        $job->{state} = STATE_BEGIN;
    }

    my $id = $self->getNextJobSetId();
    $self->redis->zadd('anyjob:jobsets', $jobSet->{time} + $self->getJobSetCleanTimeout($jobSet), $id);
    $self->redis->set('anyjob:jobset:' . $id, encode_json($jobSet));
    $self->parent->incActiveJobSetCount();

    foreach my $job (@{$jobSet->{jobs}}) {
        delete $job->{state};
    }

    $self->debug('Create jobset \'' . $id . '\' with props ' . encode_json($jobSet->{props}) .
        ' and jobs ' . encode_json($jobSet->{jobs}));

    $self->sendEvent(EVENT_CREATE_JOBSET, {
            id    => $id,
            props => $jobSet->{props},
            jobs  => $jobSet->{jobs}
        });

    foreach my $job (@{$jobSet->{jobs}}) {
        my $node = delete $job->{node};
        $job->{jobset} = $id;
        $self->redis->rpush('anyjob:queue:' . $node, encode_json($job));
    }
}

sub cleanJobSet {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean jobset \'' . $id . '\'');

    $self->redis->zrem('anyjob:jobsets', $id);
    $self->redis->del('anyjob:jobset:' . $id);
    $self->parent->decActiveJobSetCount();
}

sub cleanBuild {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean build \'' . $id . '\'');

    $self->redis->zrem('anyjob:builds', $id);
    $self->redis->del('anyjob:build:' . $id);
}

sub getNextJobSetId {
    my $self = shift;
    return $self->redis->incr('anyjob:jobset:id');
}

1;
