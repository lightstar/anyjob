package AnyJob::Creator::Addon::Base;

###############################################################################
# Abstract base class for all creator addons implementing different ways of creating jobs.
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  07.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::EventFilter;

###############################################################################
# Construct new AnyJob::Creator::Addon::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
#     type   - string addon type used to access configuration.
#              That way each creator addon have section name in configuration file like 'creator_<type>'.
# Returns:
#     AnyJob::Creator:Addon::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{type}) and $self->{type} ne '') {
        require Carp;
        Carp::confess('No addon type provided');
    }

    my $config = $self->config->section('creator_' . $self->{type}) || {};
    $self->{eventFilter} = AnyJob::EventFilter->new(filter => $config->{event_filter});

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually AnyJob::Creator object.
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
# Run configured filter for provided private event.
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
# Run configured filter for array of private events.
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
