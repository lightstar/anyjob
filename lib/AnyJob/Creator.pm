package AnyJob::Creator;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "creator";
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub getAllJobs {
    my $self = shift;

    if (exists($self->{jobs})) {
        return $self->{jobs};
    }

    my $allNodes = $self->config->getAllNodes();

    my @jobs;
    foreach my $type (@{$self->config->getAllJobs()}) {
        my @nodes;
        foreach my $node (@$allNodes) {
            if ($self->config->isJobSupported($type, $node)) {
                push @nodes, $node;
            }
        }

        unless (scalar(@nodes)) {
            next;
        }

        my $config = $self->config->getJobConfig($type);
        my $params = $config->{params} || "[]";
        utf8::encode($params);

        eval {
            $params = decode_json($params);
        };
        if ($@) {
            $self->error("Can't decode params of job '" . $type . "': " . $params);
            next;
        }

        push @jobs, {
                type   => $type,
                nodes  => \@nodes,
                params => $params
            };
    }

    @jobs = sort { $a->{type} cmp $b->{type} } @jobs;

    $self->{jobs} = \@jobs;
    return \@jobs;
}

sub getAllProps {
    my $self = shift;

    my $config = $self->config->creator || {};
    my $props = $config->{props} || "[]";
    utf8::encode($props);

    eval {
        $props = decode_json($props);
    };
    if ($@) {
        $self->error("Can't decode props: " . $props);
        return [];
    }

    return $props;
}

sub createJob {
    my $self = shift;
    my $node = shift;
    my $type = shift;
    my $params = shift;
    my $props = shift;

    unless ($self->config->isJobSupported($type, $node)) {
        $self->error("Job with type '" . $type . "' is not supported on node '" . $node . "'");
        return;
    }

    $params ||= {};
    $props ||= {};

    $self->redis->rpush("anyjob:queue:" . $node, encode_json({
            type   => $type,
            params => $params,
            props  => $props
        }));
}

sub createJobSet {
    my $self = shift;
    my $jobs = shift;
    my $props = shift;

    unless (defined($jobs) and scalar(@$jobs)) {
        return;
    }

    $props ||= {};

    foreach my $job (@$jobs) {
        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error("Job with type '" . $job->{type} . "' is not supported on node '" . $job->{node} . "'");
            return;
        }

        $job->{params} ||= {};
        $job->{props} ||= {};

        if (exists($props->{pobserver})) {
            $job->{props}->{pobserver} = $props->{pobserver};
        }
    }

    $self->redis->rpush("anyjob:queue", encode_json({
            jobset => 1,
            props  => $props,
            jobs   => $jobs
        }));
}

sub receivePrivateEvents {
    my $self = shift;
    my $name = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;
    my @events;

    while (my $event = $self->redis->lpop("anyjob:observerq:private:" . $name)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error("Can't decode event: " . $event);
        } else {
            push @events, $event;
        }

        $count++;
        last if $count >= $limit;
    }

    return \@events;
}

1;
