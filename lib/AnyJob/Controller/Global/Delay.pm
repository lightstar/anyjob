package AnyJob::Controller::Global::Delay;

###############################################################################
# Controller which manages delayed objects and starts delayed jobs. Only one such controller in whole system must run.
#
# Author:       LightStar
# Created:      23.05.2018
# Last update:  21.06.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Base';

###############################################################################
# Method which will be called one time before beginning of processing.
#
sub init {
    my $self = shift;
    $self->updateNextDelayed();
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
    if (defined($self->{nextDelayed})) {
        $delay = $self->{nextDelayed}->{time} - time();
        if ($delay < 0) {
            $delay = 0;
        }
    }

    return $delay;
}

###############################################################################
# Method called for each received event from delay queue.
# There can be four types of events. All of them are sent by creator component.
# 1. 'Create delayed' event. Field 'create' here is arbitrary hash with create data needed by creator to identify
# this delayed object. Field 'time' is integer time in unix timestamp format identifying when to run provided jobs.
# Field 'jobs' is array of hashes where each element is either jobset with inner jobs or just one individual job.
# {
#     action => 'create',
#     create => { ... },
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
#     time => ...
# }
# 2. 'Update delayed' event. Field 'id' here is id of updated delayed object. All other fields are identical to
# 'created delayed' event.
# {
#     action => 'update',
#     id => ...,
#     create => { ... },
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
#     time => ...
# }
# 3. 'Delete delayed' event. Field 'id' here is id of deleted delayed object.
# {
#     action => 'delete',
#     id => ...
# }
# 4. 'Get delayed' event. Field 'resultq' here is name of queue where result will be sent. Field 'id' is optional
# and it is id of retrieved delayed object. If no id is given, then all delayed objects are retrived.
# {
#     action => 'get',
#     resultq => '...'
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
# Create delayed object.
#
# Arguments:
#     event - hash with create data.
#             (see 'Create delayed' event in 'processEvent' method description about fields it can contain).
#
sub processCreateAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{create}) and defined($event->{jobs}) and ref($event->{jobs}) eq 'ARRAY' and
        scalar(@{$event->{jobs}}) > 0 and defined($event->{time})) {
        $self->error('Wrong create delayed event: ' . encode_json($event));
        return;
    }

    my $id = $self->getNextDelayedId();
    my $delayed = {
        create => $event->{create},
        jobs   => $event->{jobs},
        time   => $event->{time}
    };

    $self->debug('Create delayed \'' . $id . '\' with time \'' . formatDateTime($event->{time}) . '\': ' .
        encode_json($event->{jobs}) . ' (create data: ' . encode_json($event->{create}) . ')');

    my $time = $self->getNextTime($delayed);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayed));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    if (not defined($self->{nextDelayed}) or $self->{nextDelayed}->{time} > $time) {
        $self->updateNextDelayed($id, $time);
    }
}

###############################################################################
# Update delayed object.
#
# Arguments:
#     event - hash with update data.
#             (see 'Update delayed' event in 'processEvent' method description about fields it can contain).
#
sub processUpdateAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{id}) and defined($event->{create}) and defined($event->{jobs}) and
        ref($event->{jobs}) eq 'ARRAY' and scalar(@{$event->{jobs}}) > 0 and defined($event->{time})
    ) {
        $self->error('Wrong update delayed event: ' . encode_json($event));
        return;
    }

    my $id = $event->{id};
    unless (defined($self->getDelayed($id))) {
        $self->error('No delayed object with id \'' . $id . '\' to update');
        return;
    }

    my $delayed = {
        create => $event->{create},
        jobs   => $event->{jobs},
        time   => $event->{time}
    };

    $self->debug('Update delayed \'' . $id . '\' with time \'' . formatDateTime($event->{time}) . '\': ' .
        encode_json($event->{jobs}) . ' (create data: ' . encode_json($event->{create}) . ')');

    my $time = $self->getNextTime($delayed);
    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayed));
    $self->redis->zadd('anyjob:delayed', $time, $id);

    if (defined($self->{nextDelayed}) and $self->{nextDelayed}->{id} == $id and $self->{nextDelayed}->{time} < $time) {
        $self->updateNextDelayed();
    } elsif (not defined($self->{nextDelayed}) or $self->{nextDelayed}->{time} > $time) {
        $self->updateNextDelayed($id, $time);
    }
}

###############################################################################
# Delete delayed object.
#
# Arguments:
#     event - hash with delete data.
#             (see 'Delete delayed' event in 'processEvent' method description about fields it can contain).
#
sub processDeleteAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{id})) {
        $self->error('Wrong delete delayed event: ' . encode_json($event));
        return;
    }

    my $id = $event->{id};
    unless (defined($self->getDelayed($id))) {
        $self->error('No delayed object with id \'' . $id . '\' to delete');
        return;
    }

    $self->debug('Delete delayed \'' . $id . '\'');
    $self->cleanDelayed($id);
}

###############################################################################
# Get delayed object.
#
# Arguments:
#     event - hash with get data.
#             (see 'Get delayed' event in 'processEvent' method description about fields it can contain).
#
sub processGetAction {
    my $self = shift;
    my $event = shift;

    unless (defined($event->{resultq})) {
        $self->error('Wrong get delayed event: ' . encode_json($event));
        return;
    }

    $self->debug('Get delayed to queue \'' . $event->{resultq} . '\'' .
        (defined($event->{id}) ? (' (id: \'' . $event->{id} . '\')') : ''));

    my @result;
    if (defined($event->{id})) {
        my $delayed = $self->getDelayed($event->{id});
        if (defined($delayed)) {
            $delayed->{id} = $event->{id};
            push @result, $delayed;
        }
    } else {
        my @ids = $self->redis->zrangebyscore('anyjob:delayed', '-inf', '+inf');
        foreach my $id (@ids) {
            my $delayed = $self->getDelayed($id);
            if (defined($delayed)) {
                $delayed->{id} = $id;
                push @result, $delayed;
            }
        }
    }

    @result = sort {$a->{id} <=> $b->{id}} @result;
    $self->redis->rpush($event->{resultq}, encode_json(\@result));
}

###############################################################################
# Method called by daemon component on basis of provided delay.
# Its main task is to run delayed jobs.
#
sub process {
    my $self = shift;

    unless (defined($self->{nextDelayed})) {
        return;
    }

    my $id = $self->{nextDelayed}->{id};
    my $delayed = $self->getDelayed($id);
    unless (defined($delayed)) {
        $self->updateNextDelayed();
        return;
    }

    $self->debug('Process delayed \'' . $id . '\': ' . encode_json($delayed->{jobs}));

    foreach my $job (@{$delayed->{jobs}}) {
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

    $self->cleanDelayed($id);
}

###############################################################################
# Calculate time in unix timestamp format when to process provided delayed object.
#
# Arguments:
#     delayed - hash with delayed object data.
# Returns:
#     integer time in unix timestamp format.
#
sub getNextTime {
    my $self = shift;
    my $delayed = shift;
    return $delayed->{time};
}

###############################################################################
# Update inner 'nextDelayed' object which contains information about delayed object needed to be processed next.
# Arguments here are optional and will be retrieved from storage if are not specified.
#
# Arguments:
#     id   - integer id of delayed object needed to to be processed next or undef.
#     time - integer time in unix timestamp format when to process this delayed object or undef.
#
sub updateNextDelayed {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    unless (defined($id) and defined($time)) {
        ($id, $time) = $self->redis->zrangebyscore('anyjob:delayed', '-inf', '+inf', 'WITHSCORES', 'LIMIT', '0', '1');
    }

    if (defined($id) and defined($time)) {
        $self->{nextDelayed} = {
            id   => $id,
            time => $time
        };
    } else {
        $self->{nextDelayed} = undef;
    }
}

###############################################################################
# Remove delayed object data from storage.
#
# Arguments:
#     id - integer delayed id.
#
sub cleanDelayed {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean delayed \'' . $id . '\'');

    $self->redis->zrem('anyjob:delayed', $id);
    $self->redis->del('anyjob:delayed:' . $id);
    $self->updateNextDelayed();
}

###############################################################################
# Generate next available id for new delayed object.
#
# Returns:
#     integer delayed id.
#
sub getNextDelayedId {
    my $self = shift;
    return $self->redis->incr('anyjob:delayed:id');
}

1;
