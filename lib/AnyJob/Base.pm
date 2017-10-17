package AnyJob::Base;

use strict;
use warnings;
use utf8;

use Redis;
use Sys::Syslog qw(openlog syslog closelog);

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{config}) {
        require Carp;
        Carp::confess("No config provided");
    }

    unless ($self->{type}) {
        require Carp;
        Carp::confess("No component type provider");
    }

    $self->{redis} = Redis->new(server => $self->config->redis, encoding => undef);
    $self->{node} = $self->config->node;

    openlog("anyjob-" . $self->type, "ndelay,nofatal,pid", "local0");

    return $self;
}

sub config {
    my $self = shift;
    return $self->{config};
}

sub redis {
    my $self = shift;
    return $self->{redis};
}

sub node {
    my $self = shift;
    return $self->{node};
}

sub type {
    my $self = shift;
    return $self->{type};
}

sub debug {
    my ($self, $message) = @_;
    syslog("info", $message);
}

sub error {
    my ($self, $message) = @_;
    syslog("err", $message);
}

sub DESTROY {
    closelog();
}

1;
