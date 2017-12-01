package AnyJob::Creator;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);
use AnyJob::Utils qw(getModuleName requireModule);
use AnyJob::Creator::Parser;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'creator';
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

    my $module = 'AnyJob::Creator::Addon::' . getModuleName($name);
    requireModule($module);

    $self->{addons}->{$name} = $module->new(parent => $self);
    return $self->{addons}->{$name};
}

sub checkJobs {
    my $self = shift;
    my $jobs = shift;

    if (ref($jobs) ne 'ARRAY' or scalar(@$jobs) == 0) {
        return 'no jobs';
    }

    my $error;
    foreach my $job (@$jobs) {
        if (defined($error = $self->checkJobType($job))) {
            last;
        }

        if (defined($error = $self->checkJobNodes($job))) {
            last;
        }

        unless (defined($self->checkJobParams($job->{params}, $self->config->getJobParams($job->{type})))) {
            $error = 'wrong params of job with type \'' . $job->{type} . '\'';
            last;
        }

        unless (defined($self->checkJobParams($job->{props}, $self->config->getProps()))) {
            $error = 'wrong props of job with type \'' . $job->{type} . '\'';
            last;
        }
    }

    return $error;
}

sub checkJobType {
    my $self = shift;
    my $job = shift;

    if (not defined($job->{type}) or ref($job->{type}) ne '') {
        return 'no job type';
    }

    unless (defined($self->config->getJobConfig($job->{type}))) {
        return 'unknown job type \'' . $job->{type} . '\'';
    }

    return undef;
}

sub checkJobNodes {
    my $self = shift;
    my $job = shift;

    if (not defined($job->{nodes}) or ref($job->{nodes}) ne 'ARRAY' or scalar(@{$job->{nodes}}) == 0) {
        return 'no nodes for job with type \'' . $job->{type} . '\'';
    }

    foreach my $node (@{$job->{nodes}}) {
        if (ref($node) ne '') {
            return 'wrong node for job with type \'' . $job->{type} . '\'';
        }

        unless ($self->config->isJobSupported($job->{type}, $node)) {
            return 'job with type \'' . $job->{type} . '\' is not supported on node \'' . $node . '\'';
        }
    }

    return undef;
}

sub checkJobParams {
    my $self = shift;
    my $jobParams = shift;
    my $params = shift;

    if (not defined($jobParams) or ref($jobParams) ne 'HASH') {
        return undef;
    }

    foreach my $name (keys(%$jobParams)) {
        if (ref($jobParams->{$name}) ne '') {
            return undef;
        }

        my ($param) = grep {$_->{name} eq $name} @$params;
        unless (defined($param)) {
            return undef;
        }

        unless ($self->checkJobParamType($param->{type}, $jobParams->{$name}, $param->{options})) {
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

sub checkJobParamType {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $options = shift;

    unless (defined($type) and defined($value)) {
        return undef;
    }

    if ($type eq 'flag' and $value ne '0' and $value ne '1') {
        return undef;
    }

    if ($type eq 'combo' and ref($options) eq 'ARRAY' and not grep {$_->{value} eq $value} @$options) {
        return undef;
    }

    return 1;
}

sub parseJob {
    my $self = shift;
    my $input = shift;
    my $allowedExtra = shift;

    my $parser = AnyJob::Creator::Parser->new(parent => $self, input => $input, allowedExtra => $allowedExtra);
    unless (defined($parser->prepare())) {
        return (undef, undef, $parser->errors);
    }

    $parser->parse();

    return ($parser->job, $parser->extra, $parser->errors);
}

sub createJobs {
    my $self = shift;
    my $jobs = shift;
    my $props = shift;
    $props ||= {};

    my $error = $self->checkJobs($jobs);
    if (defined($error)) {
        return $error;
    }

    unless (ref($props) eq 'HASH') {
        return 'wrong props';
    }

    my $separatedJobs = [];
    foreach my $job (@$jobs) {
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

    unless (defined($type) and defined($node) and $type ne '' and $node ne '') {
        $self->error('Called createJob with wrong parameters');
        return;
    }

    unless ($self->config->isJobSupported($type, $node)) {
        $self->error('Job with type \'' . $type . '\' is not supported on node \'' . $node . '\'');
        return;
    }

    $params ||= {};
    $props ||= {};

    $self->redis->rpush('anyjob:queue:' . $node, encode_json({
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
        $self->error('Called createJobSet with wrong jobs');
        return;
    }

    $props ||= {};

    foreach my $job (@$jobs) {
        unless (defined($job->{type}) and defined($job->{node}) and $job->{type} ne '' and $job->{node} ne '') {
            $self->error('Called createJobSet with wrong jobs');
            return;
        }

        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error('Job with type \'' . $job->{type} . '\' is not supported on node \'' . $job->{node} . '\'');
            return;
        }

        $job->{params} ||= {};
        $job->{props} ||= {};

        if (exists($props->{observer})) {
            $job->{props}->{observer} = $props->{observer};
        }
    }

    $self->redis->rpush('anyjob:queue', encode_json({
            jobset => 1,
            props  => $props,
            jobs   => $jobs
        }));
}

sub receivePrivateEvents {
    my $self = shift;
    my $name = shift;
    my $stripInternalProps = shift;

    unless (defined($name) and $name ne '') {
        $self->error('Called receivePrivateEvents with empty name');
        return [];
    }

    my $config = $self->config->section('creator') || {};
    my $limit = $config->{observe_limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;
    my @events;

    while (my $event = $self->redis->lpop('anyjob:observerq:private:' . $name)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error('Can\'t decode event: ' . $event);
        } else {
            if ($stripInternalProps) {
                $self->stripInternalPropsFromEvent($event);
            }
            push @events, $event;
        }

        $count++;
        last if $count >= $limit;
    }

    return \@events;
}

sub stripInternalPropsFromEvent {
    my $self = shift;
    my $event = shift;

    foreach my $name (@{$self->config->getInternalProps()}) {
        delete $event->{props}->{$name};
        if (exists($event->{jobs})) {
            foreach my $job (@{$event->{jobs}}) {
                delete $job->{props}->{$name};
            }
        }
    }
}

1;
