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
    my $self = shift;
    my $message = shift;
    $self->logger->debug($message);
}

sub error {
    my $self = shift;
    my $message = shift;
    $self->logger->error($message);
}

sub getJob {
    my $self = shift;
    my $id = shift;
    return $self->getObject("anyjob:job:" . $id);
}

sub getJobSet {
    my $self = shift;
    my $id = shift;
    return $self->getObject("anyjob:jobset:" . $id);
}

sub getObject {
    my $self = shift;
    my $key = shift;

    my $object = $self->redis->get($key);
    unless ($object) {
        return undef;
    }

    eval {
        $object = decode_json($object);
    };
    if ($@) {
        return undef;
    }

    return $object;
}

1;
