package AnyJob::Daemon;

use strict;
use warnings;
use utf8;

use AnyJob::Daemon::Base;
use AnyJob::Controller::Factory;
use AnyJob::Constants::Defaults qw(DEFAULT_DELAY);

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'daemon';
    my $self = $class->SUPER::new(%args);

    unless ($self->config->node ne '') {
        require Carp;
        Carp::confess('No node');
    }

    my $config = $self->config->daemon;
    $self->{daemon} = AnyJob::Daemon::Base->new(
        detached => $config->{detached},
        pidfile  => $config->{pidfile},
        delay    => $config->{delay} || DEFAULT_DELAY,
        logger   => $self->logger,
        process  => sub {$self->process()}
    );

    $self->{controllers} = AnyJob::Controller::Factory->new(parent => $self)->collect();

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
