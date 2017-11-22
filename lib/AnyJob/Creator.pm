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

        if ($param->{required} and (not defined($value) or $value eq '')) {
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

# TODO: too large method, need to refactor it somehow.
sub parseJobLine {
    my $self = shift;
    my $line = shift;
    my $allowedExtra = shift;
    $allowedExtra ||= {};

    my @args = parse_line('\s+', 0, $line || '');
    unless (scalar(@args) > 0) {
        return (undef, undef, [ {
                field => 'type',
                error => 'no job type'
            } ]);
    }

    my $job = {
        type   => shift(@args),
        nodes  => [],
        params => {},
        props  => {}
    };

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        return (undef, undef, [ {
                field => 'type',
                value => $job->{type},
                error => 'unknown job type'
            } ]);
    }

    my $nodes = { map {$_ => 1} @{$self->config->getJobNodes($job->{type})} };
    my $params = { map {$_->{name} => $_} @{$self->config->getJobParams($job->{type})} };
    my $props = { map {$_->{name} => $_} @{$self->config->getProps()} };

    my @errors;
    my %extra;
    my %args;
    foreach my $arg (@args) {
        my ($name, $value) = split(/=/, $arg);

        if ($name eq '') {
            next;
        }

        if (exists($args{$name})) {
            push @errors, {
                    arg   => $name,
                    error => 'ignored duplicate arg'
                };
            next;
        }

        $args{$name} = 1;

        unless (defined($value)) {
            $value = 1;
        }

        if (exists($params->{$name})) {
            unless ($self->checkParamType($params->{$name}->{type}, $value, $params->{$name}->{data})) {
                push @errors, {
                        field => 'params',
                        param => $name,
                        value => $value,
                        error => 'wrong param'
                    };
            } else {
                $job->{params}->{$name} = $value;
            }
        } elsif (exists($props->{$name})) {
            unless ($self->checkParamType($props->{$name}->{type}, $value, $props->{$name}->{data})) {
                push @errors, {
                        field => 'props',
                        prop  => $name,
                        value => $value,
                        error => 'wrong prop'
                    };
            } else {
                $job->{props}->{$name} = $value;
            }
        } elsif ($name eq "nodes") {
            my @nodes = split(/\s*,\s*/, $value);
            my $isAllValid = 1;
            foreach my $node (@nodes) {
                unless (exists($nodes->{$node})) {
                    $isAllValid = 0;
                    push @errors, {
                            field => 'nodes',
                            value => $node,
                            error => 'node not supported'
                        };
                }
            }
            if ($isAllValid and scalar(@nodes) > 0) {
                $job->{nodes} = \@nodes;
            }
        } else {
            my @nodes = split(/\s*,\s*/, $name);
            my $isAllValid = 1;
            foreach my $node (@nodes) {
                unless (exists($nodes->{$node})) {
                    $isAllValid = 0;
                }
            }

            if ($isAllValid and scalar(@nodes) > 0 and not exists($args{nodes})) {
                $job->{nodes} = \@nodes;
                $args{nodes} = 1;
            } elsif (exists($allowedExtra->{$name})) {
                $extra{$name} = $value;
            } else {
                push @errors, {
                        arg   => $name,
                        error => 'wrong arg'
                    };
            }
        }
    }

    if (defined($config->{defaultNodes}) and scalar(@{$job->{nodes}}) == 0) {
        $job->{nodes} = [ grep {exists($nodes->{$_})} split(/\s*,\s*/, $config->{defaultNodes}) ];
        if (scalar(@{$job->{nodes}}) > 0) {
            push @errors, {
                    field   => 'nodes',
                    value   => join(',', @{$job->{nodes}}),
                    warning => 'used default nodes'
                };
        }
    }

    if (scalar(@{$job->{nodes}}) == 0) {
        push @errors, {
                field => 'nodes',
                error => 'no nodes'
            };
    }

    foreach my $param (values(%$params)) {
        if (exists($param->{default}) and $param->{default} ne '' and
            (not exists($job->{params}->{$param->{name}}) or $job->{params}->{$param->{name}} eq '')
        ) {
            $job->{params}->{$param->{name}} = $param->{default};
            push @errors, {
                    field   => 'params',
                    param   => $param->{name},
                    value   => $param->{default},
                    warning => 'used default param value'
                };
        } elsif ($param->{required} and
            (not exists($job->{params}->{$param->{name}}) or $job->{params}->{$param->{name}} eq '')
        ) {
            push @errors, {
                    field => 'params',
                    param => $param->{name},
                    error => 'param is required'
                };
        }
    }

    foreach my $prop (values(%$props)) {
        if (exists($prop->{default}) and $prop->{default} ne '' and
            (not exists($job->{props}->{$prop->{name}}) or $job->{props}->{$prop->{name}} eq '')
        ) {
            $job->{props}->{$prop->{name}} = $prop->{default};
            push @errors, {
                    field   => 'props',
                    prop    => $prop->{name},
                    value   => $prop->{default},
                    warning => 'used default prop value'
                };
        } elsif ($prop->{required} and
            (not exists($job->{props}->{$prop->{name}}) or $job->{props}->{$prop->{name}} eq '')
        ) {
            push @errors, {
                    field => 'props',
                    prop  => $prop->{name},
                    error => 'prop is required'
                };
        }
    }

    return ($job, \%extra, \@errors);
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
