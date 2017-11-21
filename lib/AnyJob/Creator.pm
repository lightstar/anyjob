package AnyJob::Creator;

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);
use JSON::XS;

use AnyJob::Utils qw(moduleName requireModule);

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "creator";
    my $self = $class->SUPER::new(%args);
    $self->{addons} = {};
    return $self;
}

sub addon {
    my $self = shift;
    my $name = shift;

    if (exists($self->{addons}->{$name})) {
        return $self->{addons}->{$name};
    }

    my $module = 'AnyJob::Creator::Addon::' . moduleName($name);
    requireModule($module);

    $self->{addons}->{$name} = $module->new(parent => $self);
    return $self->{addons}->{$name};
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

    foreach my $param (@$params) {
        my $name = $param->{name};
        my $value = $jobParams->{$name};

        if ($param->{required} and (not defined($value) or $value eq "")) {
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

sub parseJobLine {
    my $self = shift;
    my $line = shift;

    my @args = parse_line('\s+', 0, $line || '');
    unless (scalar(@args) > 0) {
        return (undef, undef, "no job type");
    }

    my $job = {
        type   => shift(@args),
        nodes  => [],
        params => {},
        props  => {}
    };

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        return (undef, undef, "unknown job type '" . $job->{type} . "'");
    }

    my $nodes = { map {$_ => 1} @{$self->config->getJobNodes($job->{type})} };
    if (defined($config->{defaultNodes})) {
        foreach my $node (split(/\s*,\s*/, $config->{defaultNodes})) {
            if (exists($nodes->{$node})) {
                push @{$job->{nodes}}, $node;
            }
        }
    }

    my $params = { map {$_->{name} => $_} @{$self->config->getJobParams($job->{type})} };
    foreach my $param (values(%$params)) {
        if (exists($param->{default})) {
            $job->{params}->{$param->{name}} = $param->{default};
        }
    }

    my $props = { map {$_->{name} => $_} @{$self->config->getProps()} };
    foreach my $prop (values(%$props)) {
        if (exists($prop->{default})) {
            $job->{props}->{$prop->{name}} = $prop->{default};
        }
    }

    my $extra = {};
    foreach my $arg (@args) {
        my ($name, $value) = split(/=/, $arg);

        unless (defined($name)) {
            return (undef, "wrong arg '" . $arg . "'");
        }

        unless (defined($value)) {
            $value = 1;
        }

        if (exists($params->{$name})) {
            $job->{params}->{$name} = $value;
        } elsif (exists($props->{$name})) {
            $job->{props}->{$name} = $value;
        } elsif ($name eq "nodes") {
            $job->{nodes} = [ split(/\s*,\s*/, $value) ];
        } else {
            my @nodes;
            foreach my $node (split(/\s*,\s*/, $name)) {
                if (exists($nodes->{$node})) {
                    push @nodes, $node;
                }
            }
            if (scalar(@nodes) > 0) {
                $job->{nodes} = \@nodes;
            } else {
                $extra->{$name} = $value;
            }
        }
    }

    return ($job, $extra, undef);
}

sub createJobs {
    my $self = shift;
    my $jobs = shift;
    my $observer = shift;
    my $props = shift;
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
            $job->{props}->{observer} = $props->{observer};
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
            $self->stripObserverFromEvent($event);
            push @events, $event;
        }

        $count++;
        last if $count >= $limit;
    }

    return \@events;
}

sub stripObserverFromEvent {
    my $self = shift;
    my $event = shift;

    if (exists($event->{props}->{observer})) {
        delete $event->{props}->{observer};
    }
    if (exists($event->{jobs})) {
        foreach my $job (@{$event->{jobs}}) {
            if (exists($job->{props}->{observer})) {
                delete $job->{props}->{observer};
            }
        }
    }
}

1;
