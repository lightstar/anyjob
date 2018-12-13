package AnyJob::Creator;

###############################################################################
# Creator component subclassed from AnyJob::Base, which primary task is to create new jobs and jobsets.
# There are several creation ways which are implemented as creator addons under 'Creator\Addon' package path.
# Creator also manages special 'private' observers which are intended to deliver event messages directly
# to clients who created appropriate jobs.
# Additionally creator can delay jobs by creating delayed works and do various actions with them.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  13.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Utils qw(getModuleName requireModule);
use AnyJob::DateTime qw(parseDateTime);
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
# If 'params' and/or 'props' fields are absent, empty ones are automatically created.
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

    my $error = undef;
    foreach my $job (@$jobs) {
        if (defined($error = $self->checkJobType($job))) {
            last;
        }

        if (defined($error = $self->checkJobNodes($job))) {
            last;
        }

        $job->{params} ||= {};
        $job->{props} ||= {};

        unless (defined($self->checkJobParams($job->{params}, $self->config->getJobParams($job->{type})))) {
            $error = 'wrong params of job with type \'' . $job->{type} . '\'';
            last;
        }

        my $props = $self->config->getJobProps($job->{type});
        unless (defined($props)) {
            $props = $self->config->getProps();
        }

        unless (defined($self->checkJobParams($job->{props}, $props))) {
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

    if ($type eq 'datetime' and defined($value) and $value ne '' and not defined(parseDateTime($value))) {
        return undef;
    }

    return 1;
}

###############################################################################
# Check delay data used to delay jobs.
#
# Arguments:
#     delay - hash with delay data. It should contain 'summary' field with string delayed work summary,
#             optional 'time' field with integer delay time in unix timestamp format and optional 'id' field with
#             integer delayed work id.
# Returns:
#     string error message or undef if there are no any errors.
#
sub checkDelay {
    my $self = shift;
    my $delay = shift;

    unless (defined($delay) and ref($delay) eq 'HASH') {
        return 'wrong delay data';
    }

    unless (defined($delay->{summary}) and $delay->{summary} ne '') {
        return 'wrong delayed work summary';
    }

    if (defined($delay->{time}) and ($delay->{time} !~ /^\d+$/o or $delay->{time} <= 0)) {
        return 'wrong delay time';

    }

    if (defined($delay->{id}) and ($delay->{id} !~ /^\d+$/o or $delay->{id} <= 0)) {
        return 'wrong delayed work id';
    }

    return undef;
}

###############################################################################
# Parse given input which can be string command-line or array of string command-line arguments.
# Result is some job(s) to create and/or some action with delayed work.
# See AnyJob::Creator::Parser module for details.
#
# Arguments:
#     input         - string input line or array of string arguments.
#     allowedExtra  - hash with allowed additional parameters.
#     options       - optional hash with additional options given to AnyJob::Creator::Parser module.
# Returns:
#     hash with parsed delay information or undef in case of error or lack of action with delayed work.
#     hash with parsed job information or undef in case of error.
#     hash with parsed extra parameters or undef in case of error.
#     array of hashes with errors/warnings.
#
sub parse {
    my $self = shift;
    my $input = shift;
    my $allowedExtra = shift;
    my $options = shift;

    my $parser = AnyJob::Creator::Parser->new(
        parent       => $self,
        (ref($input) eq 'ARRAY' ? (args => $input) : (input => $input)),
        allowedExtra => $allowedExtra,
        options      => $options
    );
    $parser->parse();

    return +($parser->delay, $parser->job, $parser->extra, $parser->errors);
}

###############################################################################
# Create jobs using provided array. For each job in it jobset or job is created depending on number of nodes and
# job configuration.
# At first created jobs are checked using 'checkJobs' method, and creating fails if there are any errors.
#
# Arguments:
#     jobs  - array of hashes with job information. I.e.:
#             [{
#                type => '...',
#                nodes => [ 'node1', 'node2', ... ],
#                params => { 'param1' => '...', 'param2' => '...', ... },
#                props => { 'prop1' => '...', 'prop2' => '...', ... }
#             }, ...]
#     props - hash with properties injected into all jobs if any.
#
# Returns:
#     string error message or undef if there are no any errors.
#
sub createJobs {
    my $self = shift;
    my $jobs = shift;
    my $props = shift;

    my ($preparedJobs, $error) = $self->prepareJobs($jobs, $props);
    if (defined($error)) {
        return $error;
    }

    foreach my $job (@$preparedJobs) {
        if ($job->{isJobSet}) {
            $self->createJobSet($job->{jobSetType}, $job->{jobs}, $job->{jobs}->[0]->{props});
        } else {
            $self->createJob($job->{jobs}->[0]);
        }
    }

    return undef;
}

###############################################################################
# Delay jobs using provided delay data and jobs array.
# At first delay data is checked using 'checkDelay' method, delayed jobs are checked using 'checkJobs' method,
# and delaying fails if there are any errors.
#
# Arguments:
#     delay - hash with delay data. It should contain 'summary' field with delayed work summary, 'time' field with
#             integer delay time in unix timestamp format and optional 'id' field with integer delayed work id.
#             If 'id' field is specified, already existing delayed work will be updated.
#     jobs  - array of hashes with job information. I.e.:
#             [{
#                type => '...',
#                nodes => [ 'node1', 'node2', ... ],
#                params => { 'param1' => '...', 'param2' => '...', ... },
#                props => { 'prop1' => '...', 'prop2' => '...', ... }
#             }, ...]
#     props - hash with properties injected into all jobs if any.
#
# Returns:
#     string error message or undef if there are no any errors.
#
sub delayJobs {
    my $self = shift;
    my $delay = shift;
    my $jobs = shift;
    my $props = shift;
    $props ||= {};

    my $error = $self->checkDelay($delay);
    if (defined($error)) {
        return $error;
    }

    my $preparedJobs;
    ($preparedJobs, $error) = $self->prepareJobs($jobs, $props);
    if (defined($error)) {
        return $error;
    }

    my @delayedJobs;
    foreach my $job (@$preparedJobs) {
        foreach my $innerJob (@{$job->{jobs}}) {
            foreach my $name (keys(%{$innerJob->{props}})) {
                unless (exists($props->{$name})) {
                    $props->{$name} = $innerJob->{props}->{$name};
                }
            }
            $innerJob->{props}->{delayed} = 1;
        }

        unless ($job->{isJobSet}) {
            push @delayedJobs, $job->{jobs}->[0];
        } else {
            push @delayedJobs, {
                (defined($job->{jobSetType}) ? (type => $job->{jobSetType}) : ()),
                jobset => 1,
                jobs   => $job->{jobs},
                props  => $job->{jobs}->[0]->{props}
            };
        }
    }

    if (defined($delay->{id})) {
        $self->updateDelayedWork($delay->{id}, $delay->{summary}, $delay->{time}, \@delayedJobs, $props);
    } else {
        $self->createDelayedWork($delay->{summary}, $delay->{time}, \@delayedJobs, $props);
    }

    return undef;
}

###############################################################################
# Prepare jobs for creating or delaying using provided array.
# At first all jobs are checked using 'checkJobs' method, and preparing fails if there are any errors.
# Each prepared job is a hash with the following fields:
#     'jobs'       - array of hashes with 'node', 'type', 'params' and 'props' fields.
#     'isJobSet'   - 0/1 flag. If set, jobset must be created, otherwise - just one separate job. In later case
#                    'jobs' array always contains just one element.
#     'jobSetType' - string jobset type or undef. Exists only if 'isJobSet' flag is set.
#
# Arguments:
#     jobs  - array of hashes with job information. I.e.:
#             [{
#                type => '...',
#                nodes => [ 'node1', 'node2', ... ],
#                params => { 'param1' => '...', 'param2' => '...', ... },
#                props => { 'prop1' => '...', 'prop2' => '...', ... }
#             }, ...]
#     props - hash with properties injected into all jobs if any.
#
# Returns:
#     array of hashes with prepared jobs or undef in case of any error.
#     string error message or undef if there are no any errors.
#
sub prepareJobs {
    my $self = shift;
    my $jobs = shift;
    my $props = shift;
    $props ||= {};

    my $error = $self->checkJobs($jobs);
    if (defined($error)) {
        return +(undef, $error);
    }

    unless (ref($props) eq 'HASH') {
        return +(undef, 'wrong props');
    }

    my @preparedJobs;
    foreach my $job (@$jobs) {
        foreach my $name (keys(%$props)) {
            unless (exists($job->{props}->{$name})) {
                $job->{props}->{$name} = $props->{$name};
            }
        }

        my $jobConfig = $self->config->getJobConfig($job->{type}) || {};
        my $jobSetType = $jobConfig->{jobset};
        my $isJobSet = (scalar(@{$job->{nodes}}) == 1 and
            (not defined($jobSetType) or $jobConfig->{no_jobset_for_loner})) ? 0 : 1;

        push @preparedJobs, {
            jobs     => [
                map {{
                    node   => $_,
                    type   => $job->{type},
                    params => $job->{params},
                    props  => $job->{props}
                }} @{$job->{nodes}}
            ],
            isJobSet => $isJobSet,
            ($isJobSet ? (jobSetType => $jobSetType) : ())
        };
    }

    return +(\@preparedJobs, undef);
}

###############################################################################
# Create one job on given node.
# Almost nothing is checked here so better use higher level method 'createJobs' instead.
#
# Arguments:
#     job - hash with job data. It should contain string fields 'type', 'node' and inner hashes 'params' and 'props'.
#
sub createJob {
    my $self = shift;
    my $job = shift;

    unless (defined($job->{type}) and defined($job->{node}) and $job->{type} ne '' and $job->{node} ne '' and
        defined($job->{params}) and ref($job->{params}) eq 'HASH' and defined($job->{props}) and
        ref($job->{props}) eq 'HASH'
    ) {
        $self->error('Called createJob with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:queue:' . $job->{node}, encode_json({
        type   => $job->{type},
        params => $job->{params},
        props  => $job->{props}
    }));
}

###############################################################################
# Create jobset.
# Almost nothing is checked here so better use higher level method 'createJobs' instead.
#
# Arguments:
#     type   - string jobset type (optional, can be undef).
#     jobs   - arrays of hashes with information about jobs to create. Each hash should contain string fields
#              'type', 'node' and inner hashes 'params' and 'props'.
#     props  - optional hash with jobset properties.
#
sub createJobSet {
    my $self = shift;
    my $type = shift;
    my $jobs = shift;
    my $props = shift;
    $props ||= {};

    unless (defined($jobs) and ref($jobs) eq 'ARRAY' and scalar(@$jobs) > 0 and ref($props) eq 'HASH') {
        $self->error('Called createJobSet with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:queue', encode_json({
        (defined($type) ? (type => $type) : ()),
        jobset => 1,
        props  => $props,
        jobs   => $jobs
    }));
}

###############################################################################
# Create delayed work.
# Almost nothing is checked here so better use higher level method 'delayJobs' instead.
#
# Arguments:
#     summary - string delayed work summary.
#     time    - integer delay time in unix timestamp format.
#     jobs    - arrays of hashes with jobs to delay. Each element is either jobset with inner jobs array or
#               individual job.
#     props   - optional hash with delayed work properties.
#
sub createDelayedWork {
    my $self = shift;
    my $summary = shift;
    my $time = shift;
    my $jobs = shift;
    my $props = shift;

    unless (defined($summary) and $summary ne '' and defined($jobs) and ref($jobs) eq 'ARRAY' and scalar(@$jobs) > 0 and
        defined($time) and $time =~ /^\d+$/o and $time > 0 and
        (not defined($props) or ref($props) eq 'HASH')
    ) {
        $self->error('Called createDelayedWork with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:delayq', encode_json({
        action  => 'create',
        summary => $summary,
        time    => $time,
        jobs    => $jobs,
        props   => $props
    }));
}

###############################################################################
# Update delayed work.
# Almost nothing is checked here so better use higher level method 'delayJobs' instead.
#
# Arguments:
#     id      - integer delayed work id to update.
#     summary - string delayed work summary.
#     time    - integer delay time in unix timestamp format.
#     jobs    - arrays of hashes with jobs to delay. Each element is either jobset with inner jobs array or
#               individual job.
#     props - optional hash with delayed work properties.
#
sub updateDelayedWork {
    my $self = shift;
    my $id = shift;
    my $summary = shift;
    my $time = shift;
    my $jobs = shift;
    my $props = shift;

    unless (defined($id) and $id =~ /^\d+$/o and $id > 0 and defined($summary) and $summary ne '' and
        defined($jobs) and ref($jobs) eq 'ARRAY' and scalar(@$jobs) > 0 and
        defined($time) and $time =~ /^\d+$/o and $time > 0 and
        (not defined($props) or ref($props) eq 'HASH')
    ) {
        $self->error('Called updateDelayedWork with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:delayq', encode_json({
        action  => 'update',
        id      => $id,
        summary => $summary,
        time    => $time,
        jobs    => $jobs,
        props   => $props
    }));
}

###############################################################################
# Delete delayed work.
#
# Arguments:
#     id    - integer delayed work id to delete.
#     props - optional hash with some properties or undef. If exists, all of them will be injected into finally
#             generated 'delete delayed work' event.
#
sub deleteDelayedWork {
    my $self = shift;
    my $id = shift;
    my $props = shift;

    unless (defined($id) and $id =~ /^\d+$/o and $id > 0 and (not defined($props) or ref($props) eq 'HASH')) {
        $self->error('Called deleteDelayedWork with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:delayq', encode_json({
        action => 'delete',
        id     => $id,
        (defined($props) ? (props => $props) : ())
    }));
}

###############################################################################
# Get delayed works.
#
# Arguments:
#     observer - string private observer name which will receive resulting 'get delayed works' event with response.
#     id       - optional integer delayed work id to get. If not provided, all delayed works are retrieved.
#     props    - optional hash with some properties or undef. If exists, all of them will be sent back with
#                generated 'get delayed works' event.
#
sub getDelayedWorks {
    my $self = shift;
    my $observer = shift;
    my $id = shift;
    my $props = shift;

    unless (defined($observer) and (not defined($id) or ($id =~ /^\d+$/o and $id > 0)) and
        (not defined($props) or ref($props) eq 'HASH')
    ) {
        $self->error('Called getDelayedWorks with wrong parameters');
        return;
    }

    $self->redis->rpush('anyjob:delayq', encode_json({
        action   => 'get',
        observer => $observer,
        (defined($id) ? (id => $id) : ()),
        (defined($props) ? (props => $props) : ())
    }));
}

1;
