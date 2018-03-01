package AnyJob::Creator::Addon::Base;

###############################################################################
# Abstract base class for all creator addons implementing different ways of creating jobs.
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  01.03.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::EventFilter;
use AnyJob::Access::User;

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

    my $config = $self->config->getCreatorConfig($self->{type}) || {};
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
# Retrieve array with detailed information about all jobs accesible by specified user.
# All jobs nodes, parameters and properties are filtered by user's access too.
#
# Arguments:
#     user - string user name.
# Returns:
#     array of hashes with jobs data. Details about its structure see in 'getAllJobs' method of AnyJob::Config class.
#
sub getUserJobs {
    my $self = shift;
    my $user = shift;

    if (exists($self->{userJobs}->{$user})) {
        return $self->{userJobs}->{$user};
    }

    my $config = $self->config;
    my $userAccess = $self->getUserAccess($user);

    $self->{userJobs}->{$user} = [];
    foreach my $job (@{$config->getAllJobs()}) {
        unless ($job->{access}->hasAccess($userAccess)) {
            next;
        }

        my $jobCopy = { %$job };
        delete $jobCopy->{access};

        my $nodesAccess = $job->{nodes}->{access};
        my $nodes = [ grep {not exists($nodesAccess->{$_}) or $nodesAccess->{$_}->hasAccess($userAccess)}
            @{$job->{nodes}->{available}} ];
        my $nodesHash = { map {$_ => 1} @$nodes };
        my $defaultNodes = { map {$_ => 1} grep {exists($nodesHash->{$_})} keys(%{$job->{nodes}->{default}}) };

        $jobCopy->{nodes} = {
            available => $nodes,
            default   => $defaultNodes
        };

        $jobCopy->{params} = [];
        foreach my $param (@{$job->{params}}) {
            unless ($param->{access}->hasAccess($userAccess)) {
                next;
            }
            my $paramCopy = { %$param };
            delete $paramCopy->{access};
            push @{$jobCopy->{params}}, $paramCopy;
        }

        if (exists($job->{props})) {
            $jobCopy->{props} = [];
            foreach my $prop (@{$job->{props}}) {
                unless ($prop->{access}->hasAccess($userAccess)) {
                    next;
                }
                my $propCopy = { %$prop };
                delete $propCopy->{access};
                push @{$jobCopy->{props}}, $propCopy;
            }
        }

        push @{$self->{userJobs}->{$user}}, $jobCopy;
    }

    return $self->{userJobs}->{$user};
}

###############################################################################
# Retrieve array with detailed information about all job properties accesible by specified user.
#
# Arguments:
#     user - string user name.
# Returns:
#     array of hashes with properties data. Details about its structure see in documentation.
#     Note that 'access' field is removed here.
#
sub getUserProps {
    my $self = shift;
    my $user = shift;

    if (exists($self->{userProps}->{$user})) {
        return $self->{userProps}->{$user};
    }

    my $userAccess = $self->getUserAccess($user);
    $self->{userProps}->{$user} = [];
    foreach my $prop (@{$self->config->getProps()}) {
        unless ($prop->{access}->hasAccess($userAccess)) {
            next;
        }
        my $propCopy = { %$prop };
        delete $propCopy->{access};
        push @{$self->{userProps}->{$user}}, $propCopy;
    }

    return $self->{userProps}->{$user};
}

###############################################################################
# Retrieve instance of AnyJob::Access:User class which represents access given to specified user.
#
# Arguments:
#     user - string user name.
# Returns:
#     AnyJob::Access:User object.
#
sub getUserAccess {
    my $self = shift;
    my $user = shift;

    if (exists($self->{userAccess}->{$user})) {
        return $self->{userAccess}->{$user};
    }

    my $config = $self->config->section('creator_' . $self->{type} . '_access') || {};
    if (exists($config->{$user})) {
        my $groups = $self->config->getAccessGroups();
        $self->{userAccess}->{$user} = AnyJob::Access::User->new(groups => $groups, input => $config->{$user});
    } else {
        $self->{userAccess}->{$user} = $AnyJob::Access::User::ACCESS_NONE;
    }

    return $self->{userAccess}->{$user};
}

###############################################################################
# Check if specified user has access to create some job. Access to job itself, its parameters and
# properties are checked here.
#
# Arguments:
#     user - string user name.
#     job  - hash with data about job this user wishes to create.
# Returns:
#     0/1 flag. If set, user is permitted to create this job, otherwise - not.
#
sub checkJobAccess {
    my $self = shift;
    my $user = shift;
    my $job = shift;

    my $userJobs = $self->getUserJobs($user);
    my $userProps = $self->getUserProps($user);

    my ($userJob) = grep {$_->{type} eq $job->{type}} @$userJobs;
    unless (defined($userJob)) {
        return 0;
    }

    foreach my $name (keys(%{$job->{params}})) {
        unless (grep {$_->{name} eq $name} @{$userJob->{params}}) {
            return 0;
        }
    }

    foreach my $name (keys(%{$job->{props}})) {
        unless (grep {$_->{name} eq $name} @$userProps) {
            return 0;
        }
    }

    return 1;
}

###############################################################################
# Abstract method which will be called by AnyJob::Creator::Observer when new private event arrives.
#
# Arguments:
#     event - hash with event data.
#
sub receivePrivateEvent {
    my $self = shift;
    my $event = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

###############################################################################
# Method called before shutdown and can be used to free all resources.
# If not overriden, does nothing.
#
sub stop {
    my $self = shift;
}

1;
