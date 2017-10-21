package AnyJob::Base;

use strict;
use warnings;
use utf8;

use Redis;
use JSON::XS;

use AnyJob::Logger;

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

    my $syslog = $self->config->syslog ? 1 : 0;
    $self->{logger} = AnyJob::Logger->new(syslog => $syslog, type => $self->{type});

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

sub logger {
    my $self = shift;
    return $self->{logger};
}

sub debug {
    my ($self, $message) = @_;
    $self->logger->debug($message);
}

sub error {
    my ($self, $message) = @_;
    $self->logger->error($message);
}

sub getJob {
    my $self = shift;
    my $id = shift;

    my $job = $self->redis->get("anyjob:job:" . $id);
    unless ($job) {
        return undef;
    }

    eval {
        $job = decode_json($job);
    };
    if ($@) {
        return undef;
    }

    return $job;
}

1;
