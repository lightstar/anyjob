package AnyJob::Controller::Base;

###############################################################################
# Abstract base class for any controller that run inside daemon component.
# Each controller performs its own specific task in 'run' method constantly called in daemon loop.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  05.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_TIMEOUT);
use AnyJob::Events qw(isValidEvent);

###############################################################################
# Construct new AnyJob::Controller::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
# Returns:
#     AnyJob::Controller::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually AnyJob::Daemon object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{parent}->config;
}

###############################################################################
# Returns:
#     Redis object.
#
sub redis {
    my $self = shift;
    return $self->{parent}->redis;
}

###############################################################################
# Returns:
#     string node name.
#
sub node {
    my $self = shift;
    return $self->{parent}->node;
}

###############################################################################
# Write debug message to log.
#
# Arguments:
#     message - string debug message.
#
sub debug {
    my $self = shift;
    my $message = shift;
    $self->{parent}->debug($message);
}

###############################################################################
# Write error message to log.
#
# Arguments:
#     message - string error message.
#
sub error {
    my $self = shift;
    my $message = shift;
    $self->{parent}->error($message);
}

###############################################################################
# Retrieve job object by id.
#
# Arguments:
#     id - integer job's id.
# Returns:
#     hash with job data.
#
sub getJob {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getJob($id);
}

###############################################################################
# Retrieve jobset object by id.
#
# Arguments:
#     id - integer jobset's id.
# Returns:
#     hash with jobset data.
#
sub getJobSet {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getJobSet($id);
}

###############################################################################
# Send event to all listening observers.
#
# Arguments:
#     name  - string event name. If that name is invalid (not known by AnyJob::Events module), nothing is sent.
#     event - hash with event data.
#
sub sendEvent {
    my $self = shift;
    my $name = shift;
    my $event = shift;

    unless (isValidEvent($name)) {
        $self->error('Unknown event \'' . $name . '\'');
        return;
    }

    $event->{event} = $name;
    $event->{node} = $self->node;
    $event->{time} = time();

    my $encodedData = encode_json($event);

    foreach my $observer (@{$self->config->getObserversForEvent($name)}) {
        $self->redis->rpush('anyjob:observerq:' . $observer, $encodedData);
    }

    my $privateObserver = $self->checkEventProp($event, 'observer', 1);
    if (defined($privateObserver)) {
        $self->redis->rpush('anyjob:observerq:private:' . $privateObserver, $encodedData);
    }
}

###############################################################################
# Check if event or appropriate job configuration contains some given property.
#
# Arguments:
#     event       - hash with event data.
#     prop        - string property name.
#     privateOnly - 0/1 flag. If set, only properties in event itself will be checked.
#                   Otherwise values in job configuration are checked too.
# Returns:
#     string property value or undef if it's not there.
#
sub checkEventProp {
    my $self = shift;
    my $event = shift;
    my $prop = shift;
    my $privateOnly = shift;

    if (exists($event->{props}) and exists($event->{props}->{$prop})) {
        return $event->{props}->{$prop};
    }

    if (not $privateOnly and exists($event->{type})) {
        my $jobConfig = $self->config->getJobConfig($event->{type});
        if ($jobConfig and exists($jobConfig->{$prop})) {
            return $jobConfig->{$prop};
        }
    }

    return undef;
}

###############################################################################
# Get timeout value for expiring and cleaning long-executed jobs.
#
# Arguments:
#     job - hash with job data.
# Returns:
#     integer timeout value in seconds.
#
sub getJobCleanTimeout {
    my $self = shift;
    my $job = shift;

    my $jobConfig = $self->config->getJobConfig($job->{type}) || {};
    my $nodeConfig = $self->config->getNodeConfig() || {};
    return $job->{props}->{clean_timeout} || $jobConfig->{clean_timeout} || $nodeConfig->{job_clean_timeout} ||
        $self->config->clean_timeout || DEFAULT_CLEAN_TIMEOUT;
}

###############################################################################
# Get timeout value for expiring and cleaning long-executed jobsets.
#
# Arguments:
#     jobset - hash with jobset data.
# Returns:
#     integer timeout value in seconds.
#
sub getJobSetCleanTimeout {
    my $self = shift;
    my $jobSet = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};
    return $jobSet->{props}->{clean_timeout} || $nodeConfig->{jobset_clean_timeout} ||
        $self->config->clean_timeout || DEFAULT_CLEAN_TIMEOUT;
}

###############################################################################
# Check if current execution of 'process' method should be delayed depending on provided delay value,
# which is actually minimal interval between executions.
#
# Arguments:
#     delay - integer delay in seconds.
# Returns:
#     0/1 flag determining if execution should be delayed.
#
sub isProcessDelayed {
    my $self = shift;
    my $delay = shift;

    if (defined($delay)) {
        my $time = time();
        if ($time - ($self->{lastTime} || 0) < $delay) {
            return 1;
        }
        $self->{lastTime} = $time;
    }

    return 0;
}

###############################################################################
# Abstract method which will be called on each iteration of daemon loop.
#
sub process {
    my $self = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

1;
