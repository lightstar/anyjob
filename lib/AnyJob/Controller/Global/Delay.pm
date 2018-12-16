package AnyJob::Controller::Global::Delay;

###############################################################################
# Controller which manages delayed works and starts jobs they contain. Only one such controller in the whole system
# must run.
#
# Author:       LightStar
# Created:      23.05.2018
# Last update:  16.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events;
use AnyJob::Constants::Delay;
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
# 1. 'Create delayed work' event. Field 'summary' here is arbitrary string needed to describe this delayed work.
# Field 'time' is integer time in unix timestamp format identifying when to run provided jobs.
# Field 'jobs' is array of hashes where each element is either jobset with inner jobs or just one individual job.
# Field 'props' is optional hash with arbitrary properties binded to work.
# Field 'opts' is optional hash with options impacting the operation.
# {
#     action => 'create',
#     summary => '...',
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
#     ],
#     props => { prop1 => '...', prop2 => '...', ... },
#     opts => { opt1 => '...', opt2 => '...', ... }
# }
# 2. 'Update delayed work' event. Field 'id' here is id of updated delayed work. All other fields are identical to
# 'create delayed work' event.
# {
#     action => 'update',
#     id => ...,
#     summary => '...',
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
#     ],
#     props => {...},
#     opts => {...}
# }
# 3. 'Delete delayed work' event. Field 'id' here is id of deleted delayed work.
# Field 'props' is optional hash with some properties which will be injected into work properties in the final
# delete event and field 'opts' is optional hash with additional options impacting the operation.
# {
#     action => 'delete',
#     id => ...,
#     props => {...},
#     opts => {...}
# }
# 4. 'Get delayed works' event. Field 'observer' here is name of private observer where event with response will be
#  sent. Field 'id' is optional and it is id of retrieved delayed work. If no id is given, then all delayed works are
# retrieved. Field 'props' is optional hash with some properties which will be sent to observer with response event and
# field 'opts' is optional hash with additional options impacting the operation.
# {
#     action => 'get',
#     observer => '...',
#     id => ...,
#     props => {...},
#     opts => {...}
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

    my $id = $self->getNextDelayedWorkId();
    my $delayedWork = {
        summary => $event->{summary},
        time    => $event->{time},
        update  => 1,
        jobs    => $event->{jobs},
        props   => $event->{props} || {}
    };

    $delayedWork->{props}->{author} ||= DELAY_AUTHOR_UNKNOWN;
    $delayedWork->{props}->{time} = time();

    $self->debug('Create delayed work \'' . $id . '\' with summary \'' . $delayedWork->{summary} . '\', time \'' .
        formatDateTime($delayedWork->{time}) . '\', jobs ' . encode_json($delayedWork->{jobs}) . ' and props ' .
        encode_json($delayedWork->{props}));

    my $time = $self->getNextTime($delayedWork);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    $self->sendEvent(EVENT_CREATE_DELAYED_WORK, {
        id        => $id,
        summary   => $delayedWork->{summary},
        delayTime => $delayedWork->{time},
        workJobs  => $delayedWork->{jobs},
        props     => $delayedWork->{props}
    });

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

    my $id = $event->{id};
    my $oldDelayedWork = $self->getDelayedWork($id);
    unless (defined($oldDelayedWork)) {
        $self->error('No delayed work with id \'' . $id . '\' to update');
        $self->sendStatusEvent($event, 0, 'Error: delayed work not found');
        return;
    }

    if (exists($event->{opts}->{check_update}) and $event->{opts}->{check_update} != $oldDelayedWork->{update}) {
        $self->error('Update count for delayed work with id \'' . $id . '\' was changed');
        $self->sendStatusEvent($event, 0, 'Error: update count was changed');
        return;
    }

    my $delayedWork = {
        summary => $event->{summary},
        time    => $event->{time},
        update  => $oldDelayedWork->{update} + 1,
        jobs    => $event->{jobs},
        props   => $event->{props} || {}
    };

    $delayedWork->{props}->{author} ||= DELAY_AUTHOR_UNKNOWN;
    $delayedWork->{props}->{time} = time();

    $self->debug('Update delayed work \'' . $id . '\' with summary \'' . $delayedWork->{summary} . '\', time \'' .
        formatDateTime($delayedWork->{time}) . '\', update count \'' . $delayedWork->{update} . '\', jobs ' .
        encode_json($delayedWork->{jobs}) . ' and props ' . encode_json($delayedWork->{props})
    );

    my $time = $self->getNextTime($delayedWork);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    $self->sendStatusEvent($event, 1, 'Delayed work updated');

    $self->sendEvent(EVENT_UPDATE_DELAYED_WORK, {
        id        => $id,
        summary   => $delayedWork->{summary},
        delayTime => $delayedWork->{time},
        workJobs  => $delayedWork->{jobs},
        props     => $delayedWork->{props}
    });

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

    my $id = $event->{id};
    my $delayedWork = $self->getDelayedWork($id);
    unless (defined($delayedWork)) {
        $self->error('No delayed work with id \'' . $id . '\' to delete');
        $self->sendStatusEvent($event, 0, 'Error: delayed work not found');
        return;
    }

    if (exists($event->{opts}->{check_update}) and $event->{opts}->{check_update} != $delayedWork->{update}) {
        $self->error('Update count for delayed work with id \'' . $id . '\' was changed');
        $self->sendStatusEvent($event, 0, 'Error: update count was changed');
        return;
    }

    $self->debug('Delete delayed work \'' . $id . '\'');
    $self->cleanDelayedWork($id);

    my $props = $delayedWork->{props};
    if (defined($event->{props})) {
        $props = { %$props };
        my @keys = keys(%{$event->{props}});
        @{$props}{@keys} = @{$event->{props}}{@keys};
    }

    $self->sendStatusEvent($event, 1, 'Delayed work removed');

    $self->sendEvent(EVENT_DELETE_DELAYED_WORK, {
        id        => $id,
        summary   => $delayedWork->{summary},
        delayTime => $delayedWork->{time},
        workJobs  => $delayedWork->{jobs},
        props     => $props
    });
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

    unless (defined($event->{observer}) and $event->{observer} ne '') {
        $self->error('No observer in get delayed works event: ' . encode_json($event));
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
        event => EVENT_GET_DELAYED_WORKS,
        works => \@delayedWorksArray,
        props => $event->{props} || {}
    }));
}

###############################################################################
# Send status event to private observer.
#
# Arguments:
#     event   - hash with processing event data.
#     success - 0/1 flag. If set, operation was successfull, otherwise - not.
#     message - status message to send.
#
sub sendStatusEvent {
    my $self = shift;
    my $event = shift;
    my $success = shift;
    my $message = shift;

    unless (exists($event->{opts}->{status_service}) and exists($event->{props}->{observer})) {
        return;
    }

    my $props = { %{$event->{props}} };
    $props->{service} = $event->{opts}->{status_service};

    $self->redis->rpush('anyjob:observerq:private:' . $event->{props}->{observer}, encode_json({
        event   => EVENT_STATUS,
        success => $success ? 1 : 0,
        message => $message,
        props   => $props
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

    $self->sendEvent(EVENT_PROCESS_DELAYED_WORK, {
        id        => $id,
        summary   => $delayedWork->{summary},
        delayTime => $delayedWork->{time},
        workJobs  => $delayedWork->{jobs},
        props     => $delayedWork->{props}
    });

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
