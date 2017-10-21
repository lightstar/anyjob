package AnyJob::Controller::Factory;

use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{parent}) {
        require Carp;
        Carp::confess("No parent provided");
    }

    return $self;
}

sub config {
    my $self = shift;
    return $self->{parent}->config;
}

sub collect {
    my $self = shift;

    $self->{controllers} = [];

    if ($self->config->isNodeGlobal()) {
        $self->pushController("global");
        foreach my $name (@AnyJob::Controller::Global::MODULES) {
            $self->pushController("global", $name);
        }
    }

    if ($self->config->isNodeRegular()) {
        $self->pushController("node");
        foreach my $name (@AnyJob::Controller::Node::MODULES) {
            $self->pushController("node", $name);
        }
    }

    foreach my $observer (@{$self->config->getNodeObservers()}) {
        my $observerConfig = $self->config->getObserverConfig($observer);
        unless ($observerConfig and $observerConfig->{module}) {
            require Carp;
            Carp::confess("No config or module for observer '" . $observer . "' provided");
        }

        $self->pushController("observer", $observerConfig->{module}, name => $observer);
    }

    return $self->{controllers};
}

sub pushController {
    my $self = shift;
    my $type = shift;
    my $name = shift;

    my $module = "AnyJob::Controller::" . ucfirst($type) . ($name ? "::" . ucfirst($name) : "");
    eval "require " . $module;
    if ($@) {
        require Carp;
        Carp::confess("Module '" . $module . "' does not exists");
    }

    push @{$self->{controllers}}, $module->new(parent => $self->{parent}, @_);
}

1;