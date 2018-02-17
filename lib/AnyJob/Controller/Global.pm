package AnyJob::Controller::Global;

###############################################################################
# Controller which manages creating and running jobsets. Only one such controller in whole system must run
# (as it's name, 'global', suggests).
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  16.02.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_CREATE_JOBSET);
use AnyJob::Constants::States qw(STATE_BEGIN);

use base 'AnyJob::Controller::Base';

###############################################################################
# Array with names of additional, also global, controllers which must run along.
#
our @MODULES = qw(
    Progress
    Clean
    BuildClean
    );

###############################################################################
# Get array of all possible event queues.
#
# Returns:
#     array of string queue names.
#
sub getEventQueues {
    my $self = shift;
    return [ 'anyjob:queue' ];
}

###############################################################################
# Method called for each received event from new jobsets queue.
# It also can process events with only one job inside redirecting it to queue of the right node (for that
# it must contain string 'node' field).
# There can be two types of events.
# 1. 'Create jobset' event. Sent by creator component.
# {
#     jobs => [ {
#         type => '...',
#         node => '...',
#         params => { param1 => '...', param2 => '...', ... },
#         props => { prop1 => '...', prop2 => '...', ... }
#     }, ... ]
#     props => { prop1 => '...', prop2 => '...', ... }
# }
# 2. 'Create job' event. Sent by creator component. Obviously provided 'node' field is required here.
# {
#     type => '...',
#     node => '...',
#     params => { param1 => '...', param2 => '...', ... },
#     props => { prop1 => '...', prop2 => '...', ... }
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{node})) {
        my $node = delete $event->{node};
        if (defined($node) and $node ne '') {
            $self->redis->rpush('anyjob:queue:' . $node, encode_json($event));
        } else {
            $self->error('No node in event: ' . encode_json($event));
        }
    } elsif (exists($event->{jobset})) {
        $self->createJobSet($event);
    }
}

###############################################################################
# Register new jobset and create all jobs contained inside.
#
# Arguments:
#     event - hash with create data.
#
sub createJobSet {
    my $self = shift;
    my $event = shift;

    foreach my $job (@{$event->{jobs}}) {
        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' . $job->{node} .
                '\'. Entire jobset discarded: ' . encode_json($event));
            return;
        }
    }

    my $jobSet = {
        jobs  => $event->{jobs},
        props => $event->{props},
        state => STATE_BEGIN,
        time  => time()
    };

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

###############################################################################
# Remove jobset data from storage.
#
# Arguments:
#     id - integer jobset id.
#
sub cleanJobSet {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean jobset \'' . $id . '\'');

    $self->redis->zrem('anyjob:jobsets', $id);
    $self->redis->del('anyjob:jobset:' . $id);
    $self->parent->decActiveJobSetCount();
}

###############################################################################
# Remove creator's build data from storage.
#
# Arguments:
#     id - integer build id.
#
sub cleanBuild {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean build \'' . $id . '\'');

    $self->redis->zrem('anyjob:builds', $id);
    $self->redis->del('anyjob:build:' . $id);
}

###############################################################################
# Generate next available id for new jobset.
#
# Returns:
#     integer jobset id.
#
sub getNextJobSetId {
    my $self = shift;
    return $self->redis->incr('anyjob:jobset:id');
}

1;
