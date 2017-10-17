package AnyJob::Controller;

use strict;
use warnings;
use utf8;

use AnyJob::Daemon;
use AnyJob::NodeController;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "controller";
    my $self = $class->SUPER::new(%args);

    $self->{daemon} = AnyJob::Daemon->new(config => $self->config, process => sub {$self->process()});

    if ($self->config->isNodeGlobal()) {
        require AnyJob::GlobalController;
        $self->{globalController} = AnyJob::GlobalController->new(parent => $self);
    }

    $self->{nodeController} = AnyJob::NodeController->new(parent => $self);

    return $self;
}

sub run {
    my $self = shift;
    $self->{daemon}->run();
}

sub process {
    my $self = shift;

    if ($self->{globalController}) {
        $self->{globalController}->processQueue();
        $self->{globalController}->processProgressQueue();
        $self->{globalController}->processResultQueue();
    }

    $self->{nodeController}->processQueue();
    $self->{nodeController}->processProgressQueue();
    $self->{nodeController}->processResultQueue();
}

1;
