package AnyJob::Controller::Observer;

###############################################################################
# Controller which manages observing and processing events in one specific queue.
# Only one controller in whole system must run for each such queue.
# It is abstract class as there may be may ways to deal with that events and such details must be handled by
# descendants.
#
# Author:       LightStar
# Created:      19.10.2017
# Last update:  05.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_TIMEOUT);
use AnyJob::DateTime qw(formatDateTime);
use AnyJob::EventFilter;

use base 'AnyJob::Controller::Base';

###############################################################################
# Construct new AnyJob::Controller::Observer object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
#     name   - non-empty string with observer name which is also used as queue name.
# Returns:
#     AnyJob::Controller::Observer object.
#
sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
    }

    my $config = $self->getObserverConfig() || {};
    $self->{eventFilter} = AnyJob::EventFilter->new(filter => $config->{event_filter});

    return $self;
}

###############################################################################
# Returns:
#     string observer name.
#
sub name {
    my $self = shift;
    return $self->{name};
}

###############################################################################
# Get observer configuration or undef.
#
# Returns:
#     hash with observer configuration or undef if there are no such observer in config.
#
sub getObserverConfig {
    my $self = shift;
    return $self->config->getObserverConfig($self->name);
}

###############################################################################
# Method called on each iteration of daemon loop.
# Its main task is to receive events from this observer queue and to process them using abstract method 'processEvent'
# which must be implemented in descendants.
# Also it calls 'cleanLogs' to clean too long stayed collected logs (see below).
# There are two types of events: job-related and jobset-related.
# 1. Job-related events have this structure (many fields are optional here, related to specific event types
# or even conflicting with each other):
# {
#     event => '...',
#     node => '...',
#     time => ...,
#     id => ...,
#     jobset => ...,
#     type => '...',
#     params => { param1 => '...', param2 => '...', ... },
#     props => { prop1 => '...', prop2 => '...', ... },
#     progress => { state => '...', progress => '...', log => { time => ..., message => '...' } },
#     success => ...,
#     message => '...'
# }
# 2. And jobset-related events have this structure (many fields here are also optional or related to specific
# event types):
# {
#     event => '...',
#     node => '...',
#     time => ...,
#     id => ...,
#     jobs => [ {
#         id => ...,
#         type => '...',
#         node => '...',
#         state => '...',
#         progress => '...',
#         params => { ... },
#         props => { ... },
#     }, ... ],
#     props => { prop1 => '...', prop2 => '...', ... },
#     progress => { state => '...', progress => '...' }
# }
#
sub process {
    my $self = shift;

    my $observerConfig = $self->getObserverConfig() || {};

    if ($self->isProcessDelayed($observerConfig->{delay} || $self->config->observe_delay)) {
        return;
    }

    my $limit = $observerConfig->{limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $event = $self->redis->lpop('anyjob:observerq:' . $self->name)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error('Can\'t decode event: ' . $event);
        } else {
            $self->processEvent($event);
        }

        $count++;
        last if $count >= $limit;
    }

    $self->cleanLogs();
}

###############################################################################
# Abstract method which will be called to process specific event.
#
# Arguments:
#     event - hash with event data.
#
sub processEvent {
    my $self = shift;
    my $event = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

###############################################################################
# Prepare event for further processing and check if it needs processing at all.
# Inject 'job' (hash with job configuration if this is job-related event) and 'config'
# (hash with observer configuration) fields into event data. Any configured filter is also applied here.
# Descendants encouraged to overload it and append its own logic.
#
# Arguments:
#     config - hash with observer configuration.
#     event  - hash with event data.
#
# Returns:
#     0/1 flag. If set, event should be processed, otherwise skipped.
#
sub preprocessEvent {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    if ($self->checkEventProp($event, 'silent', 0)) {
        return 0;
    }

    unless ($self->eventFilter($event)) {
        return 0;
    }

    $event->{config} = $config;
    if (exists($event->{type})) {
        $event->{job} = $self->config->getJobConfig($event->{type}) || {};
    }

    if ($event->{time}) {
        $event->{time} = formatDateTime($event->{time});
    }

    return 1;
}

###############################################################################
# Save log message from this job-related progress event into intermediate storage in order to collect all logs
# later when job is finished.
#
# Arguments:
#     event  - hash with event data.
#
sub saveLog {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id}) and exists($event->{progress}) and exists($event->{progress}->{log})) {
        return;
    }

    my $observerConfig = $self->getObserverConfig() || {};
    my $clean_timeout = $event->{props}->{log_clean_timeout} || $observerConfig->{log_clean_timeout} ||
        $self->config->clean_timeout || DEFAULT_CLEAN_TIMEOUT;

    $self->redis->zadd('anyjob:observer:' . $self->name . ':log', time() + $clean_timeout, $event->{id});
    $self->redis->rpush('anyjob:observer:' . $self->name . ':log:' . $event->{id},
        encode_json($event->{progress}->{log}));
}

###############################################################################
# Collect all logs saved previously using provided event (usually 'finish' event but that's not strictly
# required, it just must contain 'id' field with job id).
# Collected logs are auto-removed from storage.
#
# Arguments:
#     event  - hash with event data.
# Returns:
#     array of hashes with log data:
#      [ {
#           time => '...',
#           message => '...'
#      }, ... ]
#     Notice that time is returned as formatted string value.
#
sub collectLogs {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id})) {
        return [];
    }

    my @logs = $self->redis->lrange('anyjob:observer:' . $self->name . ':log:' . $event->{id}, '0', '-1');
    foreach my $log (@logs) {
        eval {
            $log = decode_json($log);
        };
        if ($@) {
            $self->error('Can\'t decode log: ' . $log);
            return [];
        }

        if (exists($log->{time})) {
            $log->{time} = formatDateTime($log->{time});
        }
    }

    $self->cleanLog($event->{id});

    return \@logs;
}

###############################################################################
# Clean all saved logs that stayed too long (more than configured timeout time).
#
sub cleanLogs {
    my $self = shift;

    my $observerConfig = $self->getObserverConfig() || {};
    my $limit = $observerConfig->{log_clean_limit} || $self->config->limit || DEFAULT_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:observer:' . $self->name . ':log', '-inf', time(),
        'WITHSCORES', 'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanLog($id);
    }
}

###############################################################################
# Clean logs for specific job id.
#
# Arguments:
#     id  - integer job id.
#
sub cleanLog {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean logs in observer \'' . $self->name . '\' for job \'' . $id . '\'');

    $self->redis->zrem('anyjob:observer:' . $self->name . ':log', $id);
    $self->redis->del('anyjob:observer:' . $self->name . ':log:' . $id);
}

###############################################################################
# Run configured filter for provided event.
#
# Arguments:
#     event - hash with event data.
# Returns:
#     0/1 flag. If set, event should be processed, otherwise skipped.
#
sub eventFilter {
    my $self = shift;
    my $event = shift;
    return $self->{eventFilter}->filter($event);
}

###############################################################################
# Run configured filter for array of events.
#
# Arguments:
#     events - array of hashes with event data.
# Returns:
#     array of hashes with filtered events that should be processed.
#
sub filterEvents {
    my $self = shift;
    my $events = shift;
    return [ grep {$self->{eventFilter}->filter($_)} @$events ];
}

1;
