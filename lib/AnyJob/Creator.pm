package AnyJob::Creator;

###############################################################################
# Creator component subclassed from AnyJob::Base, which primary task is to create new jobs and jobsets.
# There are several creation ways which are implemented as creator addons under 'Creator\Addon' package path.
# Creator also manages special 'private' observers which are intended to deliver event messages directly
# to clients who created appropriate jobs.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  04.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT);
use AnyJob::Utils qw(getModuleName requireModule);
use AnyJob::Creator::Parser;

use base 'AnyJob::Base';

###############################################################################
# Construct new AnyJob::Creator object.
#
# Returns:
#     AnyJob::Creator object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'creator';
    my $self = $class->SUPER::new(%args);
    $self->{addons} = {};
    return $self;
}

###############################################################################
# Get addon object by its name.
#
# Arguments:
#     name - string addon name.
# Returns:
#     addon object usually inherited from AnyJob::Creator::Addon::Base class.
#
sub addon {
    my $self = shift;
    my $name = shift;

    if (exists($self->{addons}->{$name})) {
        return $self->{addons}->{$name};
    }

    my $module = 'AnyJob::Creator::Addon::' . getModuleName($name);
    eval {
        requireModule($module);
    };
    if ($@) {
        $self->error('Error loading module \'' . $module . '\': ' . $@);
        return undef;
    }

    $self->{addons}->{$name} = $module->new(parent => $self);
    return $self->{addons}->{$name};
}

###############################################################################
# Check given array of hashes with information about jobs to create.
# Each hash should contain 'type' (string job type), 'nodes' (array of strings with node names),
# 'params' (hash with job parameters) and 'props' (hash with job properties) fields.
# All of it will be checked for correctness.
#
# Arguments:
#     jobs - array of hashes with job information.
# Returns:
#     string error message or undef if there are no any errors.
#
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

###############################################################################
# Check type of given job to create.
#
# Arguments:
#     job - hash with job information. Only its field 'type' will be checked.
# Returns:
#     string error message or undef if there are no any errors.
#
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

###############################################################################
# Check nodes of given job to create.
#
# Arguments:
#     job - hash with job information. Only its field 'nodes' will be checked.
# Returns:
#     string error message or undef if there are no any errors.
#
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

###############################################################################
# Check given job parameters for correctness.
#
# Arguments:
#     jobParams - hash with job parameters.
#     params    - array of hashes with all available job parameters from configuration.
# Returns:
#     1/undef on success/error accordingly.
#
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

###############################################################################
# Check that given parameter value is correct considering its configured type.
#
# Arguments:
#     type    - string parameter type.
#     value   - string parameter value.
#     options - array of strings with all available values, used if parameter type is 'combo'.
# Returns:
#     1/undef on success/error accordingly.
#
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

###############################################################################
# Parse given input which can be string command-line or array of string command-line arguments.
# Result is some job(s) to create.
# See AnyJob::Creator::Parser module for details.
#
# Arguments:
#     input         - string input line or array of string arguments.
#     allowedExtra  - hash with allowed additional parameters.
# Returns:
#     hash with parsed job information.
#     hash with parsed extra parameters.
#     array of hashes with errors/warnings.
#
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

###############################################################################
# Create provided jobs. If there is only one job, it will be created by itself,
# otherwise jobset is created containing all jobs.
# At first created jobs are checked using 'checkJobs' method, and creating fails if there are any errors.
#
# Arguments:
#     jobs - array of hashes with job information. I.e.:
#            [{
#                type => '...',
#                nodes => [ 'node1', 'node2', ... ],
#                params => { 'param1' => '...', 'param2' => '...', ... },
#                props => { 'prop1' => '...', 'prop2' => '...', ... }
#            }, ...]
#     props - hash with properties injected into all jobs and jobset if any.
# Returns:
#     string error message or undef if there are no any errors.
#
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

###############################################################################
# Create one job on given node.
# Almost nothing is checked here so better use higher level method 'createJobs' instead.
#
# Arguments:
#     node   - string node where to create.
#     type   - string job type.
#     params - optional hash with job parameters.
#     props  - optional hash with job properties.
#
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

###############################################################################
# Create jobset.
# Almost nothing is checked here so better use higher level method 'createJobs' instead.
#
# Arguments:
#     jobs   - arrays of hashes with information about jobs to create. Each hash should contain string fields
#              'type', 'node' and optionally inner hashes 'params' and 'props'.
#     props  - optional hash with jobset properties.
#
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
    }

    $self->redis->rpush('anyjob:queue', encode_json({
            jobset => 1,
            props  => $props,
            jobs   => $jobs
        }));
}

###############################################################################
# Receive private events dedicated to specific creator addon or even some client who used that addon.
#
# Arguments:
#     name                - some string name uniquely signifying event target (it could be addon name,
#                           addon client name or anything that is meaningfull for that addon).
#     stripInternalProps  - 0/1 flag. If set, all configured internal properties will be stripped from all events.
# Returns:
#     array of hashes with event data. Details about what event data can contain see in documentation.
#
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

###############################################################################
# Strip all configured internal properties from provided event.
#
# Arguments:
#     event - hash with event data. Details about what event data can contain see in documentation.
#
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
