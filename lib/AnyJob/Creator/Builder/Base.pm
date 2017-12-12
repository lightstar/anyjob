package AnyJob::Creator::Builder::Base;

###############################################################################
# Base abstract class for all builders used to create jobs in some specific way, not necessarily in one step.
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  11.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CLEAN_TIMEOUT);

###############################################################################
# Construct new AnyJob::Creator::Builder::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
#     name   - non-empty string with builder's name used to distinguish builders in configuration and other places.
# Returns:
#     AnyJob::Creator::Builder::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
    }

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
# Returns:
#     string builder's name.
#
sub name {
    my $self = shift;
    return $self->{name};
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
# Retrieve build object by id.
#
# Arguments:
#     id - integer build's id.
# Returns:
#     hash with build data. It's content is implementation dependent.
#
sub getBuild {
    my $self = shift;
    my $id = shift;
    return $self->{parent}->getObject('anyjob:build:' . $id);
}

###############################################################################
# Get timeout value for expiring and cleaning long-existed builds.
#
# Returns:
#     integer timeout value in seconds.
#
sub getCleanTimeout {
    my $self = shift;

    my $config = $self->config->section('creator_' . $self->name) || {};
    return $config->{build_clean_timeout} || $self->config->clean_timeout || DEFAULT_CLEAN_TIMEOUT;
}

###############################################################################
# Remove build data from storage.
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
# Generate next available id for new build.
#
# Returns:
#     integer build id.
#
sub getNextBuildId {
    my $self = shift;
    return $self->{parent}->redis->incr('anyjob:build:id');
}

1;
