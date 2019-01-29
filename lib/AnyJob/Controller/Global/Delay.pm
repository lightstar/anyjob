package AnyJob::Controller::Global::Delay;

###############################################################################
# Controller which manages delayed works and starts jobs they contain. Only one such controller in the whole system
# must run.
#
# Author:       LightStar
# Created:      23.05.2018
# Last update:  29.01.2019
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events;
use AnyJob::Constants::Delay;
use AnyJob::DateTime qw(formatDateTime);
use AnyJob::Crontab::Factory;

use base 'AnyJob::Controller::Base';

###############################################################################
# Construct new AnyJob::Controller::Global::Delay object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
# Returns:
#     AnyJob::Controller::Global::Delay object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{crontab} = AnyJob::Crontab::Factory->new();
    return $self;
}

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
# Field 'time' is integer time in unix timestamp format identifying when to run provided jobs. This field is optional
# and will have value '0' by default.
# Field 'crontab' is string crontab specification. This field is optional. If it exists, field 'time' is ignored.
# Field 'skip' is used together with 'crontab' field and it is integer skip count before actual work processing.
# Field 'pause' is used together with 'crontab' field and it is 0/1 flag. If it is set, work will not be processed.
# Field 'jobs' is array of hashes where each element is either jobset with inner jobs or just one individual job.
# Field 'props' is optional hash with arbitrary properties binded to work.
# Field 'opts' is optional hash with options impacting the operation.
# {
#     action => 'create',
#     summary => '...',
#     time => ...,
#     crontab => '...',
#     skip => ...,
#     pause => ...,
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
# 'create delayed work' event. Fields 'summary', 'time', 'crontab', 'skip', 'pause' and 'jobs' are optional and
# will not be changed if not present. If field 'time' is present, then 'crontab', 'skip' and 'pause' fields are
# ignored altogether. If field 'jobs' is not present, field 'props' is ignored.
# {
#     action => 'update',
#     id => ...,
#     summary => '...',
#     time => ...,
#     crontab => '...',
#     skip => ...,
#     pause => ...,
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

    my $time = $event->{time} || 0;
    my $crontab = $event->{crontab};

    if (defined($crontab)) {
        $time = undef;
    }

    my $delayedWork = {
        summary => $event->{summary},
        (defined($time) ? (time => $time) : ()),
        (defined($crontab) ? (
            crontab => $crontab,
            skip    => $event->{skip} || 0,
            pause   => $event->{pause} || 0
        ) : ()),
        update  => 1,
        jobs    => $event->{jobs},
        props   => $event->{props} || {}
    };

    $delayedWork->{props}->{author} ||= DELAY_AUTHOR_UNKNOWN;
    $delayedWork->{props}->{time} = time();

    $self->debug('Create delayed work \'' . $id . '\' with summary \'' . $delayedWork->{summary} . '\'' .
        (exists($delayedWork->{time}) ? ', time \'' . formatDateTime($delayedWork->{time}) . '\'' : '') .
        (exists($delayedWork->{crontab}) ? ', crontab \'' . $delayedWork->{crontab} . '\'' .
            ($delayedWork->{skip} ? ', skip \'' . $delayedWork->{skip} . '\'' : '') .
            ($delayedWork->{pause} ? ', paused' : '') : '') .
        ', jobs ' . encode_json($delayedWork->{jobs}) . ' and props ' . encode_json($delayedWork->{props}));

    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));

    $self->sendEvent(EVENT_CREATE_DELAYED_WORK, $self->getDelayedWorkEventData($id, $delayedWork));

    $self->scheduleDelayedWork($id, $delayedWork);
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
        $self->sendStatusEvent($event, 0, 'Delayed work not found');
        return;
    }

    if (exists($event->{opts}->{check_update}) and $event->{opts}->{check_update} != $oldDelayedWork->{update}) {
        $self->error('Update count for delayed work with id \'' . $id . '\' was changed');
        $self->sendStatusEvent($event, 0, 'Update count was changed');
        return;
    }

    my $summary = exists($event->{summary}) ? $event->{summary} : $oldDelayedWork->{summary};
    my $time = exists($event->{time}) ? $event->{time} : $oldDelayedWork->{time};
    my $crontab = exists($event->{crontab}) ? $event->{crontab} : $oldDelayedWork->{crontab};
    my $skip = exists($event->{skip}) ? $event->{skip} : $oldDelayedWork->{skip};
    my $isPaused = exists($event->{pause}) ? $event->{pause} : $oldDelayedWork->{pause};

    if (exists($event->{crontab})) {
        $time = undef;
    } elsif (exists($event->{time})) {
        $crontab = undef;
    }

    $time ||= 0;
    if (defined($crontab)) {
        $time = undef;
    }

    my $jobs = $oldDelayedWork->{jobs};
    my $props = $oldDelayedWork->{props};
    if (exists($event->{jobs})) {
        $jobs = $event->{jobs};
        $props = $event->{props};
    }

    my $delayedWork = {
        summary => $summary,
        (defined($time) ? (time => $time) : ()),
        (defined($crontab) ? (
            crontab => $crontab,
            skip    => $skip || 0,
            pause   => $isPaused || 0
        ) : ()),
        update  => $oldDelayedWork->{update} + 1,
        jobs    => $jobs,
        props   => $props || {}
    };

    $delayedWork->{props}->{author} ||= DELAY_AUTHOR_UNKNOWN;
    $delayedWork->{props}->{time} = time();

    $self->debug('Update delayed work \'' . $id . '\' with summary \'' . $delayedWork->{summary} . '\'' .
        (exists($delayedWork->{time}) ? ', time \'' . formatDateTime($delayedWork->{time}) . '\'' : '') .
        (exists($delayedWork->{crontab}) ? ', crontab \'' . $delayedWork->{crontab} . '\'' .
            ($delayedWork->{skip} ? ', skip \'' . $delayedWork->{skip} . '\'' : '') .
            ($delayedWork->{pause} ? ', paused' : '') : '') .
        ', update count \'' . $delayedWork->{update} . '\', jobs ' . encode_json($delayedWork->{jobs}) .
        ' and props ' . encode_json($delayedWork->{props})
    );

    $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));

    $self->sendStatusEvent($event, 1, 'Delayed work updated');
    $self->sendEvent(EVENT_UPDATE_DELAYED_WORK, $self->getDelayedWorkEventData($id, $delayedWork));

    $self->scheduleDelayedWork($id, $delayedWork);
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
        $self->sendStatusEvent($event, 0, 'Delayed work not found');
        return;
    }

    if (exists($event->{opts}->{check_update}) and $event->{opts}->{check_update} != $delayedWork->{update}) {
        $self->error('Update count for delayed work with id \'' . $id . '\' was changed');
        $self->sendStatusEvent($event, 0, 'Update count was changed');
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
    $delayedWork->{props} = $props;

    $self->sendStatusEvent($event, 1, 'Delayed work removed');
    $self->sendEvent(EVENT_DELETE_DELAYED_WORK, $self->getDelayedWorkEventData($id, $delayedWork));
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

    if (exists($delayedWork->{crontab}) and ($delayedWork->{skip} > 0 or $delayedWork->{pause})) {
        $self->skipDelayedWork($id, $delayedWork);
        return;
    }

    $self->debug('Process delayed work \'' . $id . '\': ' . encode_json($delayedWork->{jobs}));

    $self->sendEvent(EVENT_PROCESS_DELAYED_WORK, $self->getDelayedWorkEventData($id, $delayedWork));

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

    if (exists($delayedWork->{crontab})) {
        $self->scheduleDelayedWork($id, $delayedWork);
    } else {
        $self->cleanDelayedWork($id);
    }
}

###############################################################################
# Skip processing delayed work. Processing is skipped if skip counter is greater than zero or pause flag is set.
# Skip counter is decreased only if pause flag is not set.
#
# Arguments:
#     id          - integer delayed work id.
#     delayedWork - hash with delayed work data.
#
sub skipDelayedWork {
    my $self = shift;
    my $id = shift;
    my $delayedWork = shift;

    $self->debug('Skip delayed work \'' . $id . '\'' .
        ($delayedWork->{skip} > 0 ? ', skip \'' . $delayedWork->{skip} . '\'' : '') .
        ($delayedWork->{pause} ? ', paused' : '') . ', jobs : ' . encode_json($delayedWork->{jobs}));

    if ($delayedWork->{skip} > 0 and not $delayedWork->{pause}) {
        $delayedWork->{skip}--;
        $self->redis->set('anyjob:delayed:' . $id, encode_json($delayedWork));
    }

    $self->scheduleDelayedWork($id, $delayedWork);
}

###############################################################################
# Schedule delayed work processing. In case of error delayed work is automatically removed, so scheduling data
# should be previously checked for correctness.
#
# Arguments:
#     id          - integer delayed work id.
#     delayedWork - hash with delayed work data.
#
sub scheduleDelayedWork {
    my $self = shift;
    my $id = shift;
    my $delayedWork = shift;

    my $nextDelayedWork = $self->{nextDelayedWork};

    my ($nextTime, $error) = $self->getNextTime($delayedWork);
    if (defined($error)) {
        $self->error('Error scheduling delayed work \'' . $id . '\', work will be removed: ' . $error);

        $self->redis->zrem('anyjob:delayed', $id);
        $self->redis->del('anyjob:delayed:' . $id);

        if (defined($nextDelayedWork) and $nextDelayedWork->{id} == $id) {
            $self->updateNextDelayedWork();
        }

        return;
    }

    $self->redis->zadd('anyjob:delayed', $nextTime, $id);

    if (not defined($nextDelayedWork) or $nextDelayedWork->{time} >= $nextTime) {
        $self->updateNextDelayedWork($id, $nextTime);
    } elsif (defined($nextDelayedWork) and $nextDelayedWork->{id} == $id) {
        $self->updateNextDelayedWork();
    }
}

###############################################################################
# Calculate time in unix timestamp format when to process provided delayed work.
#
# Arguments:
#     delayedWork - hash with delayed work data.
# Returns:
#     integer time in unix timestamp format or undef in case of error.
#     string error or undef.
#
sub getNextTime {
    my $self = shift;
    my $delayedWork = shift;

    if (exists($delayedWork->{time})) {
        return +($delayedWork->{time}, undef);
    } else {
        my ($scheduler, $error) = $self->{crontab}->getScheduler($delayedWork->{crontab});
        if (defined($error)) {
            return +(undef, $error);
        }
        return +($scheduler->schedule(), undef);
    }
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

    my $nextDelayedWork = $self->{nextDelayedWork};
    if (defined($nextDelayedWork) and $nextDelayedWork->{id} == $id) {
        $self->updateNextDelayedWork();
    }
}

###############################################################################
# Generate hash with data used in delayed work events.
#
# Arguments:
#     id          - integer delayed work id.
#     delayedWork - hash with delayed work data.
# Returns:
#     hash with generated data.
#
sub getDelayedWorkEventData {
    my $self = shift;
    my $id = shift;
    my $delayedWork = shift;

    return {
        id       => $id,
        summary  => $delayedWork->{summary},
        (exists($delayedWork->{time}) ? (
            delayTime => $delayedWork->{time}) : ()),
        (exists($delayedWork->{crontab}) ? (
            crontab => $delayedWork->{crontab},
            skip    => $delayedWork->{skip},
            pause   => $delayedWork->{pause}
        ) : ()),
        workJobs => $delayedWork->{jobs},
        props    => $delayedWork->{props}
    };
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
