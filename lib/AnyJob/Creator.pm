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

sub checkJobs {
    my $self = shift;
    my $jobs = shift;

    if (ref($jobs) ne "ARRAY" or scalar(@$jobs) == 0) {
        return "no jobs";
    }

    foreach my $job (@$jobs) {
        if (not defined($job->{type}) or ref($job->{type}) ne "") {
            return "no job type";
        }

        my $config = $self->config->getJobConfig($job->{type});
        unless (defined($config)) {
            return "unknown job type '" . $job->{type} . "'";
        }

        if (not defined($job->{nodes}) or ref($job->{nodes}) ne "ARRAY" or scalar(@{$job->{nodes}}) == 0) {
            return "no nodes for job with type '" . $job->{type} . "'";
        }

        foreach my $node (@{$job->{nodes}}) {
            if (ref($node) ne "") {
                return "wrong node for job with type '" . $job->{type} . "'";
            }

            unless ($self->config->isJobSupported($job->{type}, $node)) {
                return "job with type '" . $job->{type} . "' is not supported on node '" . $node . "'";
            }
        }

        if (not defined($job->{params}) or ref($job->{params}) ne "HASH") {
            return "no params for job with type '" . $job->{type} . "'";
        }

        unless (defined($self->checkParams($job->{params}, $self->config->getJobParams($job->{type})))) {
            return "wrong params of job with type '" . $job->{type} . "'";
        }

        if (not defined($job->{props}) or ref($job->{props}) ne "HASH") {
            return "no props for job with type '" . $job->{type} . "'";
        }

        unless (defined($self->checkParams($job->{props}, $self->config->getProps()))) {
            return "wrong props of job with type '" . $job->{type} . "'";
        }
    }

    return undef;
}

sub checkParams {
    my $self = shift;
    my $jobParams = shift;
    my $params = shift;

    foreach my $name (keys(%$jobParams)) {
        if (ref($jobParams->{$name}) ne "") {
            return undef;
        }

        my ($param) = grep {$_->{name} eq $name} @$params;
        unless (defined($param)) {
            return undef;
        }

        unless ($self->checkParamType($param->{type}, $jobParams->{$name}, $param->{data})) {
            return undef;
        }
    }

    return 1;
}

sub checkParamType {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $data = shift;

    if ($type eq "flag" and $value ne "0" and $value ne "1") {
        return undef;
    }

    if ($type eq "combo" and ref($data) eq "ARRAY" and not grep {$_ eq $value} @$data) {
        return undef;
    }

    return 1;
}

sub createJobs {
    my $self = shift;
    my $jobs = shift;
    my $props = shift;
    my $observer = shift;
    $props ||= {};

    my $error = $self->checkJobs($jobs);
    if (defined($error)) {
        return $error;
    }

    unless (ref($props) eq "HASH" and defined($self->checkParams($props, $self->config->getProps()))) {
        return "wrong props";
    }

    if (defined($observer)) {
        $props->{observer} = $observer;
    }

    my $separatedJobs = [];
    foreach my $job (@$jobs) {
        if (defined($observer)) {
            $job->{props}->{observer} = $observer;
        }

        foreach my $name (keys(%$props)) {
            unless (exists($job->{props}->{$name})) {
                $job->{props}->{$name} = $props->{$name};
            }
        }

        foreach my $node (@{$job->{nodes}}) {
            push @$separatedJobs, {
                    node   => $node,
                    type   => $job->{type},
                    params => $job->{params},
                    props  => $job->{props}
                };
        }
    }

    if (scalar(@$separatedJobs) == 1) {
        $self->createJob($separatedJobs->[0]->{node}, $separatedJobs->[0]->{type},
            $separatedJobs->[0]->{params}, $separatedJobs->[0]->{props});
    } elsif (scalar(@$separatedJobs) > 1) {
        $self->createJobSet($separatedJobs, $props);
    }

    return undef;
}

sub createJob {
    my $self = shift;
    my $node = shift;
    my $type = shift;
    my $params = shift;
    my $props = shift;

    unless (defined($type) and defined($node) and $type ne "" and $node ne "") {
        $self->error("Called createJob with wrong parameters");
        return;
    }

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

    unless (defined($jobs) and scalar(@$jobs) > 0) {
        $self->error("Called createJobSet with wrong jobs");
        return;
    }

    $props ||= {};

    foreach my $job (@$jobs) {
        unless (defined($job->{type}) and defined($job->{node}) and $job->{type} ne "" and $job->{node} ne "") {
            $self->error("Called createJobSet with wrong jobs");
            return;
        }

        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error("Job with type '" . $job->{type} . "' is not supported on node '" . $job->{node} . "'");
            return;
        }

        $job->{params} ||= {};
        $job->{props} ||= {};

        if (exists($props->{observer})) {
            $job->{props}->{observer} = $props->{pobserver};
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

    unless (defined($name) and $name ne "") {
        $self->error("Called receivePrivateEvents with wrong name");
        return [];
    }

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
