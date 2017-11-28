package AnyJob::Creator::Addon::Base;

use strict;
use warnings;
use utf8;

use JavaScript::Duktape;

use AnyJob::EventFilter;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{parent}) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless ($self->{type}) {
        require Carp;
        Carp::confess('No addon type provided');
    }

    my $config = $self->config->section($self->{type}) || {};
    $self->{eventFilter} = AnyJob::EventFilter->new(filter => $config->{event_filter});

    return $self;
}

sub config {
    my $self = shift;
    return $self->{parent}->config;
}

sub debug {
    my $self = shift;
    my $message = shift;
    $self->{parent}->debug($message);
}

sub error {
    my $self = shift;
    my $message = shift;
    $self->{parent}->error($message);
}

sub eventFilter {
    my $self = shift;
    my $event = shift;
    return $self->{eventFilter}->filter($event);
}

sub filterEvents {
    my $self = shift;
    my $events = shift;
    return [ grep {$self->{eventFilter}->filter($_)} @$events ];
}

1;
