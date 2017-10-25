package AnyJob::Controller::Observer;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Base';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    unless ($self->{name}) {
        require Carp;
        Carp::confess("No name provided");
    }

    $self->{queue} = $self->config->getObserverQueue($self->{name});
    unless ($self->{queue}) {
        require Carp;
        Carp::confess("No queue for observer '" . $self->{name} . "'");
    }

    return $self;
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub queue {
    my $self = shift;
    return $self->{queue};
}

sub observerConfig {
    my $self = shift;
    return $self->config->getObserverConfig($self->name);
}

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;

    while (my $event = $self->redis->lpop("anyjob:observer_queue:" . $self->queue)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error("Can't decode event: " . $event);
        } else {
            $self->processEvent($event);
        }

        $count++;
        last if $count >= $limit;
    }
}

sub processEvent {
    my $self = shift;
    my $event = shift;

    require Carp;
    Carp::confess("Need to be implemented in descendant");
}

sub checkEventProp {
    my $self = shift;
    my $event = shift;
    my $prop = shift;

    if (exists($event->{props}) and $event->{props}->{$prop}) {
        return 1;
    }

    if (exists($event->{type})) {
        my $jobConfig = $self->config->getJobConfig($event->{type});
        if ($jobConfig and $jobConfig->{$prop}) {
            return 1;
        }
    }

    return 0;
}

sub preprocessEvent {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    if ($self->checkEventProp($event, "silent")) {
        return 0;
    }

    $event->{config} = $config;

    if ($event->{time}) {
        $event->{time} = formatDateTime($event->{time});
    }

    return 1;
}

1;
