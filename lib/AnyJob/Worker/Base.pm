package AnyJob::Worker::Base;

###############################################################################
# Convenient abstract base class which all specific worker modules should extend as it contains many helper methods.
# When default worker (AnyJob::Worker) is executed, it will call method 'run' (though it's configurable) of specific
# worker module where all unique job logic should be implemented.
#
# Author:       LightStar
# Created:      27.10.2017
# Last update:  20.02.2018
#

use strict;
use warnings;
use utf8;

###############################################################################
# Construct new AnyJob::Worker::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Worker object.
#     id     - integer current job id.
#     job    - hash with information about current job. It should contain string fields 'type', 'state', integer field
#              'time', hash fields 'params' and 'props'. Also it can contain, if this job is part of jobset,
#              integer field 'jobset' with jobset id.
# Returns:
#     AnyJob::Worker::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless ($self->{id}) {
        require Carp;
        Carp::confess('No job id provided');
    }

    unless (defined($self->{job})) {
        require Carp;
        Carp::confess('No job provided');
    }

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually AnyJob::Worker object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Returns:
#     integer job id.
#
sub id {
    my $self = shift;
    return $self->{id};
}

###############################################################################
# Returns:
#     hash with job data.
#
sub job {
    my $self = shift;
    return $self->{job};
}

###############################################################################
# Returns:
#     integer jobset id or undef if current job is not part of any jobset.
#
sub jobset {
    my $self = shift;
    return $self->{job}->{jobset};
}

###############################################################################
# Returns:
#     string job type.
#
sub type {
    my $self = shift;
    return $self->{job}->{type};
}

###############################################################################
# Returns:
#     hash with job parameters.
#
sub params {
    my $self = shift;
    return $self->{job}->{params};
}

###############################################################################
# Arguments:
#     name - string parameter name.
# Returns:
#     string parameter value or undef if there are no such parameter in current job.
#
sub param {
    my $self = shift;
    my $name = shift;
    return $self->{job}->{params}->{$name};
}

###############################################################################
# Returns:
#     hash with job properties.
#
sub props {
    my $self = shift;
    return $self->{job}->{props};
}

###############################################################################
# Arguments:
#     name - string property name.
# Returns:
#     string property value or undef if there are no such property in current job.
#
sub prop {
    my $self = shift;
    my $name = shift;
    return $self->{job}->{props}->{$name};
}

###############################################################################
# Returns:
#     string current node name.
#
sub node {
    my $self = shift;
    return $self->{parent}->node;
}

###############################################################################
# Returns:
#     hash with job data loaded from storage.
#
sub getJob {
    my $self = shift;
    return $self->parent->getJob($self->id);
}

###############################################################################
# Returns:
#     hash with jobset data loaded from storage or undef if current job is not part of any jobset.
#
sub getJobSet {
    my $self = shift;
    if (defined(my $jobset = $self->jobset)) {
        return $self->parent->getJobSet($jobset);
    }
    return undef;
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
# Send message to daemon's progress queue.
#
# Arguments:
#     progress - string progress value or hash with arbitrary message data.
#
sub sendProgress {
    my $self = shift;
    my $progress = shift;
    $self->{parent}->sendProgress($self->id, $progress);
}

###############################################################################
# Send change state message to daemon's progress queue.
#
# Arguments:
#     state - string state value.
#
sub sendState {
    my $self = shift;
    my $state = shift;
    $self->{parent}->sendState($self->id, $state)
}

###############################################################################
# Send message to daemon's progress queue with some log message.
#
# Arguments:
#     message  - string log message.
#
sub sendLog {
    my $self = shift;
    my $message = shift;
    $self->{parent}->sendLog($self->id, $message);
}

###############################################################################
# Send message to daemon's progress queue redirecting job to given node.
#
# Arguments:
#     node - string node name.
#
sub sendRedirect {
    my $self = shift;
    my $node = shift;
    $self->{parent}->sendRedirect($self->id, $node);
}

###############################################################################
# Send message to daemon's progress queue successfully finishing job.
#
# Arguments:
#     message - string finish message.
#     data    - optional hash with result data.
#
sub sendSuccess {
    my $self = shift;
    my $message = shift;
    my $data = shift;
    $self->{parent}->sendSuccess($self->id, $message, $data);
}

###############################################################################
# Send message to daemon's progress queue finishing job with error.
#
# Arguments:
#     message - string finish message.
#     data    - optional hash with result data.
#
sub sendFailure {
    my $self = shift;
    my $message = shift;
    my $data = shift;
    $self->{parent}->sendFailure($self->id, $message, $data);
}

###############################################################################
# Send message to daemon's jobset progress queue.
# Nothing is sent if current job is not part of any jobset.
#
# Arguments:
#     progress - string progress value or hash with arbitrary message data.
#
sub sendJobSetProgress {
    my $self = shift;
    my $progress = shift;
    if (defined(my $jobset = $self->jobset)) {
        $self->{parent}->sendJobSetProgress($jobset, $progress);
    }
}

###############################################################################
# Send change state message to daemon's jobset progress queue.
# Nothing is sent if current job is not part of any jobset.
#
# Arguments:
#     state - string state value.
#
sub sendJobSetState {
    my $self = shift;
    my $state = shift;
    if (defined(my $jobset = $self->jobset)) {
        $self->{parent}->sendJobSetState($jobset, $state);
    }
}

###############################################################################
# Send redo message to daemon's progress queue which will lead to running this job again.
#
# Arguments:
#     id    - integer job id.
#
sub sendRedo {
    my $self = shift;
    $self->{parent}->sendRedo($self->id);
}

###############################################################################
# Abstract method which will be called to execute specific job logic and should be implemented in descendants.
#
sub run {
    my $self = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

1;
