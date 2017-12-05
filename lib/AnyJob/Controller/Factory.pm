package AnyJob::Controller::Factory;

###############################################################################
# Controller factory class which can collect all controllers needed to be executed in current node.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  05.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::Utils qw(getModuleName requireModule);

###############################################################################
# Construct new AnyJob::Controller::Factory object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
# Returns:
#     AnyJob::Controller::Factory object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{parent}) {
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
# Collect all controllers needed to be run in current node.
#
# Returns:
#     array of controllers (descendants of the AnyJob::Controller::Base class).
#
sub collect {
    my $self = shift;

    $self->{controllers} = [];

    if ($self->config->isNodeGlobal()) {
        $self->pushController('global');
        foreach my $name (@AnyJob::Controller::Global::MODULES) {
            $self->pushController('global', $name);
        }
    }

    if ($self->config->isNodeRegular()) {
        $self->pushController('node');
        foreach my $name (@AnyJob::Controller::Node::MODULES) {
            $self->pushController('node', $name);
        }
    }

    foreach my $observer (@{$self->config->getNodeObservers()}) {
        my $observerConfig = $self->config->getObserverConfig($observer);
        unless (defined($observerConfig) and defined($observerConfig->{module}) and $observerConfig->{module} ne '') {
            require Carp;
            Carp::confess('No config or module for observer \'' . $observer . '\' provided');
        }

        $self->pushController('observer', $observerConfig->{module}, name => $observer);
    }

    return $self->{controllers};
}

###############################################################################
# Instantiate and push controller object with given type and name into the internal array.
# Type and name are used to build controller module name.
#
# Arguments:
#     type - string controller type.
#     name - optional string controller name.
#     all additional arguments will be appended to arguments of controller constructor.
#
sub pushController {
    my $self = shift;
    my $type = shift;
    my $name = shift;

    my $module = 'AnyJob::Controller::' . getModuleName($type);
    if (defined($name)) {
        $module .= '::' . getModuleName($name);
    }
    requireModule($module);

    push @{$self->{controllers}}, $module->new(parent => $self->parent, @_);
}

1;
