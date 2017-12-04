package AnyJob::Base;

###############################################################################
# Abstract class for any root AnyJob component.
# Each executable should contain only one instance of that class but that's not strictly required.
# Known direct subclasses: AnyJob::Daemon, AnyJob::Creator, AnyJob::Worker.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  04.12.2017
#

use strict;
use warnings;
use utf8;

use Redis;
use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_CONFIG_FILE DEFAULT_REDIS injectPathIntoConstant);
use AnyJob::Config;
use AnyJob::Logger;

###############################################################################
# Construct new AnyJob::Base object.
#
# Arguments:
#     type - string component type. Must not be empty. Used in logging for example.
# Returns:
#     AnyJob::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{type}) and $self->{type} ne '') {
        require Carp;
        Carp::confess('No component type provider');
    }

    my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : injectPathIntoConstant(DEFAULT_CONFIG_FILE);
    $self->{config} = AnyJob::Config->new($configFile, 'anyjob');

    $self->{redis} = Redis->new(server => $self->config->redis || DEFAULT_REDIS, encoding => undef);
    $self->{node} = $self->config->node;

    my $syslog = $self->config->syslog ? 1 : 0;
    $self->{logger} = AnyJob::Logger->new(syslog => $syslog, type => $self->{type});

    return $self;
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{config};
}

###############################################################################
# Returns:
#     Redis object.
#
sub redis {
    my $self = shift;
    return $self->{redis};
}

###############################################################################
# Returns:
#     string node name.
#
sub node {
    my $self = shift;
    return $self->{node};
}

###############################################################################
# Returns:
#     string component type.
#
sub type {
    my $self = shift;
    return $self->{type};
}

###############################################################################
# Returns:
#     AnyJob::Logger object.
#
sub logger {
    my $self = shift;
    return $self->{logger};
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
    $self->logger->debug($message);
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
    $self->logger->error($message);
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
    return $self->getObject('anyjob:job:' . $id);
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
    return $self->getObject('anyjob:jobset:' . $id);
}

###############################################################################
# Retrieve some object by key.
#
# Arguments:
#     key - string object's key in data storage.
# Returns:
#     hash with object data.
#
sub getObject {
    my $self = shift;
    my $key = shift;

    my $object = $self->redis->get($key);
    unless ($object) {
        return undef;
    }

    eval {
        $object = decode_json($object);
    };
    if ($@) {
        return undef;
    }

    return $object;
}

1;
