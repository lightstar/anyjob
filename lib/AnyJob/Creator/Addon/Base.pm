package AnyJob::Creator::Addon::Base;

use strict;
use warnings;
use utf8;

use JavaScript::Duktape;

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

    $self->{js} = JavaScript::Duktape->new();

    my $config = $self->config->section($self->{type}) || {};
    $self->{js}->eval('function eventFilter() { return ' .
        (defined($config->{event_filter}) ? $config->{event_filter} : '1') .
        '; }');

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

    $self->{js}->set('event', $event);
    return $self->{js}->eval('eventFilter()') ? 1 : 0;
}

sub filterEvents {
    my $self = shift;
    my $events = shift;
    return [ grep {$self->eventFilter($_)} @$events ];
}

1;
