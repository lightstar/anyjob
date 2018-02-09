package AnyJob::Config::Selector::Factory;

###############################################################################
# Config selector factory used to create instance of appropriate selector class.
# Class name is determined based on anyjob component type.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  07.02.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Utils qw(getModuleName requireModule);

###############################################################################
# Construct new AnyJob::Config::Selector::Factory object.
#
# Arguments:
#     parent - parent component which could be any subclass of AnyJob::Base class.
# Returns:
#     AnyJob::Config::Selector::Factory object.
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
#     parent component which is subclass of AnyJob::Base class.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Choose right class and create selector object. Class name is determined based on anyjob component type.
#
# Returns:
#     selector object which is subclass of AnyJob::Selector::Base class.
#
sub build {
    my $self = shift;

    my $module = 'AnyJob::Config::Selector::' . getModuleName($self->parent->type);
    requireModule($module);

    return $module->new(config => $self->parent->config);
}

1;
