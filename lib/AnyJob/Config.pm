package AnyJob::Config;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::BaseConfig';

sub getAllNodes {
    my $self = shift;

    if ($self->{nodes}) {
        return $self->{nodes};
    }

    my @nodes;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($node) = ($section =~ /^node_(.+)$/)) {
            push @nodes, $node;
        }
    }

    $self->{nodes} = \@nodes;

    return $self->{nodes};
}

sub getAllJobs {
    my $self = shift;

    if ($self->{jobs}) {
        return $self->{jobs};
    }

    my @jobs;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($job) = ($section =~ /^job_(.+)$/)) {
            push @jobs, $job;
        }
    }

    $self->{jobs} = \@jobs;

    return $self->{jobs};
}

sub getAllObservers {
    my $self = shift;

    if ($self->{observers}) {
        return $self->{observers};
    }

    my @observers;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($observer) = ($section =~ /^observer_(.+)$/)) {
            push @observers, $observer;
        }
    }
    $self->{observers} = \@observers;

    return $self->{observers};
}

sub getObserverQueuesForEvent {
    my $self = shift;
    my $event = shift;

    $self->{observerQueues} ||= {};
    if (exists($self->{observerQueues}->{$event})) {
        return $self->{observerQueues}->{$event};
    }

    my $observerQueues = [];
    foreach my $observer (@{$self->getAllObservers()}) {
        my $config = $self->getObserverConfig($observer);
        if (not $config->{events} or $config->{events} eq "all" or
            grep {$_ eq $event} split(/\s*,\s*/, $config->{events})
        ) {
            if (not $config->{nodes} or $config->{nodes} eq "all" or
                grep {$_ eq $self->node} split(/\s*,\s*/, $config->{nodes})
            ) {
                push @$observerQueues, $config->{queue};
            }
        }
    }

    $self->{observerQueues}->{$event} = $observerQueues;
    return $observerQueues;
}

sub getJobConfig {
    my $self = shift;
    my $type = shift;
    return $self->section("job_" . $type);
}

sub getNodeConfig {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;
    return $self->section("node_" . $node);
}

sub getObserverConfig {
    my $self = shift;
    my $name = shift;
    return $self->section("observer_" . $name);
}

sub getObserverQueue {
    my $self = shift;
    my $name = shift;

    my $config = $self->getObserverConfig($name);
    return undef unless $config;

    return $config->{queue};
}

sub getJobParams {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless $config;

    return decode_json($config->{params});
}

sub getJobWorker {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless $config;

    return $config->{worker} || $self->worker;
}

sub isJobSupported {
    my $self = shift;
    my $type = shift;
    my $node = shift;
    $node ||= $self->node;

    my $config = $self->getJobConfig($type);
    return 0 unless $config;

    if (not $config->{nodes} or $config->{nodes} eq "all") {
        my $except = $config->{except} || "";
        return (grep {$_ eq $node} split(/,/, $except)) ? 0 : 1;
    }

    return (grep {$_ eq $node} split(/,/, $config->{nodes})) ? 0 : 1;
}

sub isNodeGlobal {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;

    my $config = $self->getNodeConfig($node);
    return 0 unless $config;

    return $config->{global} ? 1 : 0;
}

1;
