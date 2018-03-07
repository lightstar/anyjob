package AnyJob::Worker::Context::Base;

###############################################################################
# Convenient base class which all specific worker context modules should extend.
#
# Author:       LightStar
# Created:      05.03.2018
# Last update:  07.03.2018
#

use strict;
use warnings;
use utf8;

###############################################################################
# Construct new AnyJob::Worker::Context::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Worker object.
# Returns:
#     AnyJob::Worker::Context::Base object.
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
#     parent component which is usually AnyJob::Worker object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
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
# Called by worker component after finishing all processing. You can override it to clean any resources.
#
sub stop {
    my $self = shift;
}

1;
