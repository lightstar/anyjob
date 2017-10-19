package AnyJob::Daemon;

use strict;
use warnings;
use utf8;

use AnyJob::Daemon::Base;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "daemon";
    my $self = $class->SUPER::new(%args);

    my $config = $self->config->daemon;
    $self->{daemon} = AnyJob::Daemon::Base->new(
        detached => $config->{detached},
        pidfile  => $config->{pidfile},
        delay    => $config->{delay},
        logger   => $self->logger,
        process  => sub {$self->process()}
    );

    $self->{controllers} = [];

    if ($self->config->isNodeGlobal()) {
        require AnyJob::Controller::Global;
        push @{$self->{controllers}}, AnyJob::Controller::Global->new(parent => $self);
    }

    if ($self->config->isNodeRegular()) {
        require AnyJob::Controller::Node;
        push @{$self->{controllers}}, AnyJob::Controller::Node->new(parent => $self);
    }

    foreach my $observer (@{$self->config->getNodeObservers()}) {
        my $observerConfig = $self->config->getObserverConfig($observer);
        unless ($observerConfig and $observerConfig->{module}) {
            require Carp;
            Carp::confess("No config or module for observer '" . $observer . "' provided");
        }

        my $module = "AnyJob::Observer::" . ucfirst($observerConfig->{module});
        eval "require " . $module;
        if ($@) {
            require Carp;
            Carp::confess("Module '" . $module . "' does not exists");
        }

        push @{$self->{controllers}}, $module->new(parent => $self, name => $observer);
    }

    return $self;
}

sub run {
    my $self = shift;
    $self->{daemon}->run();
}

sub process {
    my $self = shift;

    foreach my $controller (@{$self->{controllers}}) {
        $controller->process();
    }
}

1;
