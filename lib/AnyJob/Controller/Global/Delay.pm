package AnyJob::Controller::Global::Delay;

###############################################################################
# Controller which manages delayed works and starts jobs they contain. Only one such controller in the whole system
# must run.
#
# Author:       LightStar
# Created:      23.05.2018
# Last update:  27.11.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_DELAYED_WORKS);
use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Base';

###############################################################################
# Method which will be called one time before beginning of processing.
#
sub init {
    my $self = shift;
    $self->updateNextDelayedWork();
}

###############################################################################
# Get array of all possible event queues.
#
# Returns:
#     array of string queue names.
#
sub getEventQueues {
    my $self = shift;
    return [ 'anyjob:delayq' ];
}

###############################################################################
# Get delay before next 'process' method invocation.
#
# Arguments:
#     integer delay in seconds or undef if 'process' method should not be called at all.
#
sub getProcessDelay {
    my $self = shift;

    my $delay = undef;
    if (defined($self->{nextDelayedWork})) {
        $delay = $self->{nextDelayedWork}->{time} - time();
        if ($delay < 0) {
            $delay = 0;
        }
    }

    return $delay;
}

###############################################################################
# Method called for each received event from delay queue.
# There can be four types of events. All of them are sent by creator component.
# 1. 'Create delayed work' event. Field 'name' here is arbitrary string name needed to identify this delayed work.
# Field 'time' is integer time in unix timestamp format identifying when to run provided jobs.
# Field 'jobs' is array of hashes where each element is either jobset with inner jobs or just one individual job.
# {
#     action => 'create',
#     name => '...',
#     time => ...,
#     jobs => [
#         {
#             jobset => '1',
#             jobs => [ ... ]
#         },
#         {
#             node => '...',
#             type => '...',
#             params => {...},
#             props => {...}
#         },
#         ...
#     ]
# }
# 2. 'Update delayed work' event. Field 'id' here is id of updated delayed work. All other fields are identical to
# 'create delayed work' event.
# {
#     action => 'update',
#     id => ...,
#     name => '...',
#     time => ...,
#     jobs => [
#         {
#             jobset => '1',
#             jobs => [ ... ]
#         },
#         {
#             node => '...',
#             type => '...',
#             params => {...},
#             props => {...}
#         },
#         ...
#     ]
# }
# 3. 'Delete delayed work' event. Field 'id' here is id of deleted delayed work.
# {
#     action => 'delete',
#     id => ...
# }
# 4. 'Get delayed works' event. Field 'observer' here is name of observer where event with response will be sent.
# Field 'props' is optional hash with some properties which will be sent to observer with response event.
# Field 'id' is optional and it is id of retrieved delayed work. If no id is given, then all delayed works are
# retrieved.
# {
#     action => 'get',
#     observer => '...',
#     props => {...},
#     id => ...
# }
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{action})) {
        return;
    }

    if ($event->{action} eq 'create') {
        $self->processCreateAction($event);
    } elsif ($event->{action} eq 'get') {
        $self->processGetAction($event);
    } elsif ($event->{action} eq 'update') {
        $self->processUpdateAction($event);
    } elsif ($event->{action} eq 'delete') {
        $self->processDeleteAction($event);
    }
}

###############################################################################
# Create delayed work.
#
# Arguments:
#     event - hash with create data.
#             (see 'Create delayed work' event in 'processEvent' method description about fields it can contain).
#
sub processCreateAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{name}) and $event->{name} ne '' and
        defined($event->{time}) and $event->{time} =~ /^\d+$/o and $event->{time} > 0 and
        defined($event->{jobs}) and ref($event->{jobs}) eq 'ARRAY' and scalar(@{$event->{jobs}}) > 0
    ) {
        $self->error('Wrong create delayed work event: ' . encode_json($event));
        return;
    }

    my $id = $self->getNextDelayedWorkId();
    my $delayedWork = {
        name => $event->{name},
        time => $event->{time},
        jobs => $event->{jobs}
    };

    $self->debug('Create delayed work \'' . $id . '\' with name \'' . $event->{name} . '\' and time \'' .
        formatDateTime($event->{time}) . '\': ' . encode_json($event->{jobs}));

    my $time = $self->getNextTime($delayedWork);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    if (not defined($self->{nextDelayedWork}) or $self->{nextDelayedWork}->{time} > $time) {
        $self->updateNextDelayedWork($id, $time);
    }
}

###############################################################################
# Update delayed work.
#
# Arguments:
#     event - hash with update data.
#             (see 'Update delayed work' event in 'processEvent' method description about fields it can contain).
#
sub processUpdateAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{id}) and defined($event->{name}) and $event->{name} ne '' and
        defined($event->{time}) and $event->{time} =~ /^\d+$/o and $event->{time} > 0 and
        defined($event->{jobs}) and ref($event->{jobs}) eq 'ARRAY' and scalar(@{$event->{jobs}}) > 0
    ) {
        $self->error('Wrong update delayed work event: ' . encode_json($event));
        return;
    }

    my $id = $event->{id};
    unless (defined($self->getDelayedWork($id))) {
        $self->error('No delayed work with id \'' . $id . '\' to update');
        return;
    }

    my $delayedWork = {
        name => $event->{name},
        time => $event->{time},
        jobs => $event->{jobs}
    };

    $self->debug('Update delayed work \'' . $id . '\' with name \'' . $event->{name} . '\' and time \'' .
        formatDateTime($event->{time}) . '\': ' . encode_json($event->{jobs}));

    my $time = $self->getNextTime($delayedWork);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    my $nextDelayedWork = $self->{nextDelayedWork};
    if (defined($nextDelayedWork) and $nextDelayedWork->{id} == $id and $nextDelayedWork->{time} < $time) {
        $self->updateNextDelayedWork();
    } elsif (not defined($nextDelayedWork) or $nextDelayedWork->{time} > $time) {
        $self->updateNextDelayedWork($id, $time);
    }
}

###############################################################################
# Delete delayed work.
#
# Arguments:
#     event - hash with delete data.
#             (see 'Delete delayed work' event in 'processEvent' method description about fields it can contain).
#
sub processDeleteAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{id})) {
        $self->error('Wrong delete delayed work event: ' . encode_json($event));
        return;
    }

    my $id = $event->{id};
    unless (defined($self->getDelayedWork($id))) {
        $self->error('No delayed work with id \'' . $id . '\' to delete');
        return;
    }

    $self->debug('Delete delayed work \'' . $id . '\'');
    $self->cleanDelayedWork($id);
}

###############################################################################
# Get delayed works.
#
# Arguments:
#     event - hash with get data.
#             (see 'Get delayed works' event in 'processEvent' method description about fields it can contain).
#
sub processGetAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{observer}) and (not defined($event->{props}) or ref($event->{props}) eq 'HASH')) {
        $self->error('Wrong get delayed works event: ' . encode_json($event));
        return;
    }

    $self->debug('Send delayed works to observer \'' . $event->{observer} . '\'' .
        (defined($event->{id}) ? (' (id: \'' . $event->{id} . '\')') : ''));

    my @delayedWorksArray;
    if (defined($event->{id})) {
        my $delayedWork = $self->getDelayedWork($event->{id});
        if (defined($delayedWork)) {
            $delayedWork->{id} = $event->{id};
            push @delayedWorksArray, $delayedWork;
        }
    } else {
        my @ids = $self->redis->zrangebyscore('anyjob:delayed', '-inf', '+inf');
        foreach my $id (@ids) {
            my $delayedWork = $self->getDelayedWork($id);
            if (defined($delayedWork)) {
                $delayedWork->{id} = $id;
                push @delayedWorksArray, $delayedWork;
            }
        }
    }

    @delayedWorksArray = sort {$a->{id} <=> $b->{id}} @delayedWorksArray;
    $self->redis->rpush('anyjob:observerq:private:' . $event->{observer}, encode_json({
        event => EVENT_DELAYED_WORKS,
        works => \@delayedWorksArray,
        props => $event->{props} || {}
    }));
}

###############################################################################
# Method called by daemon component on basis of provided delay.
# Its main task is to run delayed works.
#
sub process {
    my $self = shift;

    unless (defined($self->{nextDelayedWork})) {
        return;
    }

    my $id = $self->{nextDelayedWork}->{id};
    my $delayedWork = $self->getDelayedWork($id);
    unless (defined($delayedWork)) {
        $self->updateNextDelayedWork();
        return;
    }

    $self->debug('Process delayed work \'' . $id . '\': ' . encode_json($delayedWork->{jobs}));

    foreach my $job (@{$delayedWork->{jobs}}) {
        if (exists($job->{jobset})) {
            $self->redis->rpush('anyjob:queue', encode_json($job));
        } else {
            my $node = $job->{node};
            if (defined($node) and $node ne '') {
                delete $job->{node};
                $self->redis->rpush('anyjob:queue:' . $node, encode_json($job));
            } else {
                $self->error('No node in job: ' . encode_json($job));
            }
        }
    }

    $self->cleanDelayedWork($id);
}

###############################################################################
# Calculate time in unix timestamp format when to process provided delayed work.
#
# Arguments:
#     delayedWork - hash with delayed work data.
# Returns:
#     integer time in unix timestamp format.
#
sub getNextTime {
    my $self = shift;
    my $delayedWork = shift;
    return $delayedWork->{time};
}

###############################################################################
# Update inner 'nextDelayedWork' object which contains information about delayed work needed to be processed next.
# Arguments here are optional and will be retrieved from storage if are not specified.
#
# Arguments:
#     id   - integer id of delayed work needed to to be processed next or undef.
#     time - integer time in unix timestamp format when to process this delayed work or undef.
#
sub updateNextDelayedWork {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    unless (defined($id) and defined($time)) {
        ($id, $time) = $self->redis->zrangebyscore('anyjob:delayed', '-inf', '+inf', 'WITHSCORES', 'LIMIT', '0', '1');
    }

    if (defined($id) and defined($time)) {
        $self->{nextDelayedWork} = {
            id   => $id,
            time => $time
        };
    } else {
        $self->{nextDelayedWork} = undef;
    }
}

###############################################################################
# Remove delayed work data from storage.
#
# Arguments:
#     id - integer delayed work id.
#
sub cleanDelayedWork {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean delayed work \'' . $id . '\'');

    $self->redis->zrem('anyjob:delayed', $id);
    $self->redis->del('anyjob:delayed:' . $id);
    $self->updateNextDelayedWork();
}

###############################################################################
# Generate next available id for new delayed work.
#
# Returns:
#     integer delayed work id.
#
sub getNextDelayedWorkId {
    my $self = shift;
    return $self->redis->incr('anyjob:delayed:id');
}

1;
