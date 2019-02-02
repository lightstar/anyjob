package AnyJob::Config;

###############################################################################
# Configuration class used to collect, store and retrieve configuration data.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  02.02.2019
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Spec;
use File::Basename;

use AnyJob::Constants::Defaults qw(
    DEFAULT_WORKER_WORK_DIR DEFAULT_WORKER_EXEC DEFAULT_WORKER_DAEMON_EXEC DEFAULT_TEMPLATES_PATH
    injectPathIntoConstant
);
use AnyJob::Constants::Delay qw(DELAY_REAL_ACTIONS);
use AnyJob::Access::Resource;

use base 'AnyJob::Config::Base';

###############################################################################
# Construct new AnyJob::Config object.
#
# Returns:
#     AnyJob::Config object.
#
sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $fileName = shift;
    $self->{baseDir} = dirname($fileName);

    return $self;
}

###############################################################################
# Returns:
#     string config base directory.
#
sub baseDir {
    my $self = shift;
    return $self->{baseDir};
}

###############################################################################
# Returns:
#     string node name retrieved from system environment.
#
sub node {
    my $self = shift;

    if (exists($self->{node})) {
        return $self->{node};
    }

    $self->{node} = $ENV{ANYJOB_NODE} || '';
    return $self->{node};
}

###############################################################################
# Add configuration from files in given directory.
#
# Arguments:
#     dirName       - root directory to search configuration files in.
#     sectionPrefix - prefix for default section. Default section will contain all configuration data
#                     without any explicit section. Final default section value for every file will be
#                     <sectionPrefix>_<fileName>. For files in additional subdirectory:
#                     <sectionPrefix>_<subdirectoryName>_<fileName>.
#
sub addConfigFromDir {
    my $self = shift;
    my $dirName = shift;
    my $sectionPrefix = shift;

    my $dh;
    if (opendir($dh, $dirName)) {
        foreach my $fileName (readdir($dh)) {
            next unless $fileName !~ /^\./;

            my $fullFileName = File::Spec->catfile($dirName, $fileName);

            if (-d $fullFileName) {
                $self->addConfigFromDir($fullFileName, $sectionPrefix . '_' . $fileName);
            }

            next unless -f $fullFileName and $fileName =~ /\.cfg$/;

            my $section = $sectionPrefix . '_' . $fileName;
            $section =~ s/\.cfg$//;
            $self->addConfig($fullFileName, $section);
        }
        closedir($dh);
    }
}

###############################################################################
# Get array of strings with names of all available nodes.
#
# Returns:
#     array of strings with names of all available nodes.
#
sub getAllNodes {
    my $self = shift;

    if (exists($self->{nodes})) {
        return $self->{nodes};
    }

    my @nodes;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($node) = ($section =~ /^node_(.+)$/)) {
            unless ($self->{data}->{$section}->{disabled}) {
                push @nodes, {
                    node => $node,
                    sort => $self->{data}->{$section}->{sort} || 0
                };
            }
        }
    }

    @nodes = map {$_->{node}} sort {$a->{sort} <=> $b->{sort} or $a->{node} cmp $b->{node}} @nodes;

    $self->{nodes} = \@nodes;
    return \@nodes;
}

###############################################################################
# Get array of hashes with detailed information about all available jobs.
# Field 'access' here contains instance of AnyJob::Access:Resource class.
# It signifies access needed to create this job.
# Values of 'nodes.access' field are hashes where keys are node names and values are instances of
# AnyJob::Access::Resource class too. They signify access needed to create job on corresponding nodes.
# Field 'delayAccess' is hash where keys are delay action names and values are again instances of
# AnyJob::Access::Resource class. They signify accesses needed to perform specified delay actions with this job.
# Field 'props' here is optional and exists only if properties for this job are overriden.
#
# Returns:
#     array of hashes with detailed information about all available jobs:
#     [{
#         type => '...',
#         nodes => {
#             available => [ 'node1', 'node2', node3', ... ],
#             default   => { 'node1' => 1, 'node2' => 1, ... },
#             min       => ...,
#             max       => ...,
#             access    => { 'node1' => ..., 'node2' => ..., ... },
#         },
#         access => ...,
#         delayAccess => { action1 => ..., action2 => ... },
#         label => '...',
#         group => '...',
#         params => [ { name => 'param1', ... }, { name => 'param2', ... }, ... ],
#         props => [ { name => 'prop1', ... }, { name => 'prop2', ... }, ... ],
#         sort => ...
#     },...]
#
sub getAllJobs {
    my $self = shift;

    if (exists($self->{jobs})) {
        return $self->{jobs};
    }

    my @jobs;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($type) = ($section =~ /^job_(.+)$/)) {
            if ($self->{data}->{$section}->{disabled}) {
                next
            }

            my $nodes = $self->getJobNodes($type);
            if (scalar(@$nodes) == 0) {
                next;
            }

            my $nodesHash = { map {$_ => 1} @$nodes };
            my $defaultNodes = { map {$_ => 1} grep {exists($nodesHash->{$_})}
                split(/\s*,\s*/, $self->{data}->{$section}->{default_nodes} || '') };

            my $props = $self->getJobProps($type);
            push @jobs, {
                type        => $type,
                nodes       => {
                    available => $nodes,
                    default   => $defaultNodes,
                    min       => $self->{data}->{$section}->{min_nodes} || 0,
                    max       => $self->{data}->{$section}->{max_nodes} || 0,
                    access    => $self->getJobNodesAccess($type)
                },
                access      => $self->getJobAccess($type),
                delayAccess => $self->getJobDelayAccess($type),
                label       => $self->{data}->{$section}->{label} || $type,
                group       => $self->{data}->{$section}->{group} || '',
                params      => $self->getJobParams($type),
                (defined($props) ? (props => $props) : ()),
                sort        => $self->{data}->{$section}->{sort} || 0
            };
        }
    }

    @jobs = sort {$a->{sort} <=> $b->{sort} or $a->{type} cmp $b->{type}} @jobs;
    foreach my $job (@jobs) {
        delete $job->{sort};
    }

    $self->{jobs} = \@jobs;
    return \@jobs;
}

###############################################################################
# Get array of strings with names of all available observers.
#
# Returns:
#     array of strings with names of all available observers.
#
sub getAllObservers {
    my $self = shift;

    if (exists($self->{observers})) {
        return $self->{observers};
    }

    my @observers;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($observer) = ($section =~ /^observer_(.+)$/)) {
            unless ($self->{data}->{$section}->{disabled}) {
                push @observers, $observer;
            }
        }
    }

    $self->{observers} = \@observers;
    return \@observers;
}

###############################################################################
# Get array of strings with names of all available builders.
#
# Returns:
#     array of strings with names of all available builders.
#
sub getAllBuilders {
    my $self = shift;

    if (exists($self->{builders})) {
        return $self->{builders};
    }

    my @builders;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($builder) = ($section =~ /^builder_(.+)$/)) {
            unless ($self->{data}->{$section}->{disabled}) {
                push @builders, $builder;
            }
        }
    }

    $self->{builders} = \@builders;
    return \@builders;
}

###############################################################################
# Get jobset configuration or undef.
#
# Arguments:
#     type - string jobset type.
# Returns:
#     hash with jobset configuration or undef if there are no such jobset type.
#
sub getJobSetConfig {
    my $self = shift;
    my $type = shift;
    return $self->section('jobset_' . $type);
}

###############################################################################
# Get job configuration or undef.
#
# Arguments:
#     type - string job type.
# Returns:
#     hash with job configuration or undef if there are no such job type.
#
sub getJobConfig {
    my $self = shift;
    my $type = shift;
    return $self->section('job_' . $type);
}

###############################################################################
# Get node configuration or undef.
#
# Arguments:
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     hash with node configuration or undef if there are no such node.
#
sub getNodeConfig {
    my $self = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    return $self->section('node_' . $node);
}

###############################################################################
# Get observer configuration or undef.
#
# Arguments:
#     name - string observer name.
# Returns:
#     hash with observer configuration or undef if there are no such observer.
#
sub getObserverConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('observer_' . $name);
}

###############################################################################
# Get creator configuration or undef.
#
# Arguments:
#     name - string creator name.
# Returns:
#     hash with creator configuration or undef if there are no such creator.
#
sub getCreatorConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('creator_' . $name);
}

###############################################################################
# Get builder configuration or undef.
#
# Arguments:
#     name - string builder name.
# Returns:
#     hash with builder configuration or undef if there are no such builder.
#
sub getBuilderConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('builder_' . $name);
}

###############################################################################
# Get worker configuration or undef.
#
# Arguments:
#     name - string worker name.
# Returns:
#     hash with worker configuration or undef if there are no such worker.
#
sub getWorkerConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('worker_' . $name);
}

###############################################################################
# Get semaphore configuration or undef.
#
# Arguments:
#     name - string semaphore name.
# Returns:
#     hash with semaphore configuration or undef if there are no such semaphore.
#
sub getSemaphoreConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('semaphore_' . $name);
}

###############################################################################
# Get crontab configuration or undef. Each key inside is some name and value is corresponding crontab specification
# string.
#
# Returns:
#     hash with crontab configuration or undef.
#
sub getCrontabConfig {
    my $self = shift;
    return $self->section('crontab');
}

###############################################################################
# Get array of strings with names of nodes where job with given type can execute.
#
# Arguments:
#     type - string job type.
# Returns:
#     array of strings with names of nodes.
#
sub getJobNodes {
    my $self = shift;
    my $type = shift;

    my @nodes;
    foreach my $node (@{$self->getAllNodes()}) {
        if ($self->isJobSupported($type, $node)) {
            push @nodes, $node;
        }
    }

    return \@nodes;
}

###############################################################################
# Get minimum allowed nodes for job with given type.
#
# Arguments:
#     type - string job type.
# Returns:
#     integer minimum nodes count. In case of 0, minimum is not set.
#
sub getJobMinNodes {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{min_nodes})) {
        return 0;
    }

    return $config->{min_nodes};
}

###############################################################################
# Get maximum allowed nodes for job with given type.
#
# Arguments:
#     type - string job type.
# Returns:
#     integer maximum nodes count. In case of 0, maximum is not set.
#
sub getJobMaxNodes {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{max_nodes})) {
        return 0;
    }

    return $config->{max_nodes};
}

###############################################################################
# Get array of hashes with detailed information about parameters for given job type.
# All possible fields in that hashes see in documentation.
# Each hash here has 'access' field which contains instance of AnyJob::Access::Resource class.
# It signifies access needed to set this parameter.
#
# Arguments:
#     type - string job type.
# Returns:
#     array of hashes with detailed parameters information.
#
sub getJobParams {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobParams}->{$type})) {
        return $self->{jobParams}->{$type};
    }

    $self->{jobParams}->{$type} = [];

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{params})) {
        return [];
    }

    my $params;
    eval {
        $params = $self->parseParams($config->{params});
    };
    if ($@) {
        require Carp;
        Carp::confess('Wrong params of job \'' . $type . '\': ' . $config->{params});
    }

    $self->{jobParams}->{$type} = $params;
    return $params;
}

###############################################################################
# Get array of hashes with detailed information about overriden properties for given job type.
# All possible fields in that hashes see in documentation.
# Each hash here has 'access' field which contains instance of AnyJob::Access::Resource class.
# It signifies access needed to set this parameter.
#
# Arguments:
#     type - string job type.
# Returns:
#     array of hashes with detailed properties information or undef if properties are not overriden.
#
sub getJobProps {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobProps}->{$type})) {
        return $self->{jobProps}->{$type};
    }

    $self->{jobProps}->{$type} = undef;

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{props})) {
        return undef;
    }

    my $props;
    eval {
        $props = $self->parseParams($config->{props});
    };
    if ($@) {
        require Carp;
        Carp::confess('Wrong props of job \'' . $type . '\': ' . $config->{props});
    }

    $self->{jobProps}->{$type} = $props;
    return $props;
}

###############################################################################
# Get hash with nodes access for given job type.
#
# Arguments:
#     type - string job type.
# Returns:
#     hash with nodes access. Each key in that hash is node name and value is appropriate instance
#     of AnyJob::Access::Resource class.
#
sub getJobNodesAccess {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobNodesAccess}->{$type})) {
        return $self->{jobNodesAccess}->{$type};
    }

    $self->{jobNodesAccess}->{$type} = {};

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{nodes_access})) {
        return {};
    }

    my $nodesAccess = $config->{nodes_access};
    eval {
        $nodesAccess = decode_json($nodesAccess);
    };
    if ($@ or ref($nodesAccess) ne 'HASH') {
        require Carp;
        Carp::confess('Wrong nodes access of job \'' . $type . '\': ' . $config->{nodes_access});
    }

    foreach my $node (keys(%$nodesAccess)) {
        $nodesAccess->{$node} = AnyJob::Access::Resource->new(input => $nodesAccess->{$node});
    }

    $self->{jobNodesAccess}->{$type} = $nodesAccess;
    return $nodesAccess;
}

###############################################################################
# Get AnyJob::Access::Resource object which represents access to job with specified type.
#
# Arguments:
#     type - string job type.
# Returns:
#     AnyJob::Access::Resource object.
#
sub getJobAccess {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobAccess}->{$type})) {
        return $self->{jobAccess}->{$type};
    }

    $self->{jobAccess}->{$type} = $AnyJob::Access::Resource::ACCESS_ANY;

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{access})) {
        return $self->{jobAccess}->{$type};
    }

    $self->{jobAccess}->{$type} = AnyJob::Access::Resource->new(input => $config->{access});
    return $self->{jobAccess}->{$type};
}

###############################################################################
# Get hash where keys are string delay actions and values are corresponding AnyJob::Access::Resource objects which
# represents access to performing specified action with job of specified type.
#
# Arguments:
#     type - string job type.
# Returns:
#     hash where keys are string delay actions and values are corresponding AnyJob::Access::Resource objects.
#
sub getJobDelayAccess {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobDelayAccess}->{$type})) {
        return $self->{jobDelayAccess}->{$type};
    }

    my $delayAccess = {};

    my $config = $self->getJobConfig($type);
    if (defined($config) and exists($config->{delay_access})) {
        eval {
            $delayAccess = decode_json($config->{delay_access});
        };
        if ($@ or ref($delayAccess) ne 'HASH') {
            require Carp;
            Carp::confess('Wrong delay access of job \'' . $type . '\': ' . $config->{delay_access});
        }
    }

    $self->{jobDelayAccess} ||= {};
    $self->{jobDelayAccess}->{$type} = {};

    foreach my $action (keys(%$delayAccess)) {
        if (exists(DELAY_REAL_ACTIONS()->{$action})) {
            $self->{jobDelayAccess}->{$type}->{$action} =
                AnyJob::Access::Resource->new(input => $delayAccess->{$action});
        }
    }

    return $self->{jobDelayAccess}->{$type};
}

###############################################################################
# Get job worker name.
#
# Arguments:
#     type - string job type.
# Returns:
#     string worker name or undef if this job configuration doesn't specify any appointed worker.
#
sub getJobWorkerName {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    my $workerSection = $self->section('worker') || {};
    return $config->{worker} || $workerSection->{worker};
}

###############################################################################
# Get job worker options as multiple returned values.
# Can return undef if job hasn't configuration.
#
# Arguments:
#     type - string job type.
# Returns:
#     string work directory for executable.
#     string executable name.
#     optional string additional libraries needed by worker executable (could be undef if there are none).
#     optional string user name to run this job under.
#     optional string group name to run this job under.
#
sub getJobWorkerOptions {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    my $workerSection = $self->section('worker') || {};

    my $worker = $config->{worker} || $workerSection->{worker};
    my $workerConfig = defined($worker) ? $self->getWorkerConfig($worker) || {} : {};

    return +(
        injectPathIntoConstant($config->{work_dir} || $workerConfig->{work_dir} || $workerSection->{work_dir} ||
            DEFAULT_WORKER_WORK_DIR),
        injectPathIntoConstant($config->{exec} || $workerConfig->{exec} || $workerSection->{exec} ||
            DEFAULT_WORKER_EXEC),
        $config->{lib} || $workerConfig->{lib} || $workerSection->{lib},
        $config->{suser} || $workerConfig->{suser} || $workerSection->{suser},
        $config->{sgroup} || $workerConfig->{sgroup} || $workerSection->{sgroup}
    );
}

###############################################################################
# Get worker daemon options as multiple returned values.
# Can return undef if worker hasn't configuration or it is not supposed to be run as daemon.
#
# Arguments:
#     name - string worker name.
# Returns:
#     string work directory for daemon.
#     string daemon executable name.
#     optional string additional libraries needed by worker daemon (could be undef if there are none).
#     optional string user name to run this worker daemon under.
#     optional string group name to run this worker daemon under.
#
sub getWorkerDaemonOptions {
    my $self = shift;
    my $name = shift;

    my $config = $self->getWorkerConfig($name);
    return undef unless defined($config) and $config->{daemon};

    my $workerSection = $self->section('worker') || {};

    return +(
        injectPathIntoConstant($config->{work_dir} || $workerSection->{work_dir} || DEFAULT_WORKER_WORK_DIR),
        injectPathIntoConstant($config->{exec} || $workerSection->{daemon_exec} || DEFAULT_WORKER_DAEMON_EXEC),
        $config->{lib} || $workerSection->{lib},
        $config->{suser} || $workerSection->{suser},
        $config->{sgroup} || $workerSection->{sgroup}
    );
}

###############################################################################
# Check if job with given type is allowed to run on particular node.
#
# Arguments:
#     type - string job type.
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     0/1 flag. If set, job is allowed to run.
#
sub isJobSupported {
    my $self = shift;
    my $type = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    if (exists($self->{jobSupported}->{$node}->{$type})) {
        return $self->{jobSupported}->{$node}->{$type};
    }

    my $result;
    my $jobConfig = $self->getJobConfig($type);
    my $nodeConfig = $self->getNodeConfig($node);

    if (not defined($jobConfig) or $jobConfig->{disabled}) {
        $result = 0;
    } elsif (not defined($nodeConfig) or $nodeConfig->{disabled} or not $nodeConfig->{regular}) {
        $result = 0;
    } elsif (not exists($jobConfig->{nodes}) or $jobConfig->{nodes} eq 'all') {
        my $except = $jobConfig->{except} || '';
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $except)) ? 0 : 1;
    } else {
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $jobConfig->{nodes})) ? 1 : 0;
    }

    $self->{jobSupported}->{$node}->{$type} = $result;

    return $result;
}

###############################################################################
# Get hash with some job's semaphores configuration. This hash will have next structure:
# {
#    '<mode>' => [ { 'name': '<name>', 'client': '<client>', 'cmode': '<clientMode>', 'jobset': '<0/1>' }, ... ],
#    ...
# }
# '<mode>' here is one of predefined semaphore mode names for entity, '<name>' is one of configured semaphore names,
# '<client>' is arbitrary client name (it is optional, string 'job' will be used by default) and
# '<clientMode>' is optional client mode ('entity', 'jobset' or 'single'). When client mode is not specified, some
# default value will be used depending on mode.
# 'jobset' is optional field. If it is set to '0', semaphore will be processed only for jobs not within any jobset, and
# if it set to '1', semaphore will be processed only for jobs within some jobset. By default all jobs are processed.
#
# Arguments:
#     type - string job type.
# Returns:
#     hash with semaphores configuration.
#
sub getJobSemaphores {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobSemaphores}->{$type})) {
        return $self->{jobSemaphores}->{$type};
    }

    $self->{jobSemaphores}->{$type} = {};

    my $config = $self->getJobConfig($type);
    unless (defined($config) and exists($config->{semaphores})) {
        return {};
    }

    my $semaphores;
    eval {
        $semaphores = $self->parseSemaphores($config->{semaphores});
    };
    if ($@) {
        require Carp;
        Carp::confess('Wrong semaphores of job \'' . $type . '\': ' . $config->{semaphores});
    }

    $self->{jobSemaphores}->{$type} = $semaphores;
    return $semaphores;
}

###############################################################################
# Get hash with some jobset's semaphores configuration. This hash will have next structure:
# {
#    '<mode>' => [ { 'name': '<name>', 'client': '<client>', 'cmode': '<clientMode>' }, ... ],
#    ...
# }
# '<mode>' here is one of predefined semaphore mode names for entity, '<name>' is one of configured semaphore names,
# '<client>' is arbitrary client name (it is optional, string 'jobset' will be used by default) and
# '<clientMode>' is optional client mode ('entity', 'jobset' or 'single'). When client mode is not specified, some
# default value will be used depending on mode.
#
# Arguments:
#     type - string jobset type.
# Returns:
#     hash with semaphores configuration.
#
sub getJobSetSemaphores {
    my $self = shift;
    my $type = shift;

    if (exists($self->{jobSetSemaphores}->{$type})) {
        return $self->{jobSetSemaphores}->{$type};
    }

    $self->{jobSetSemaphores}->{$type} = {};

    my $config = $self->getJobSetConfig($type);
    unless (defined($config) and exists($config->{semaphores})) {
        return {};
    }

    my $semaphores;
    eval {
        $semaphores = $self->parseSemaphores($config->{semaphores});
    };
    if ($@) {
        require Carp;
        Carp::confess('Wrong semaphores of jobset \'' . $type . '\': ' . $config->{semaphores});
    }

    $self->{jobSetSemaphores}->{$type} = $semaphores;
    return $semaphores;
}

###############################################################################
# Check if global controller need to be run on particular node.
# Global controller manages jobsets and some other global things.
#
# Arguments:
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     0/1 flag. If set, global controller need to be run.
#
sub isNodeGlobal {
    my $self = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    my $config = $self->getNodeConfig($node);
    return 0 unless defined($config) and not $config->{disabled};

    return $config->{global} ? 1 : 0;
}

###############################################################################
# Check if regular controller need to be run on particular node.
# Regular controller manages jobs on this node.
#
# Arguments:
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     0/1 flag. If set, regular controller need to be run.
#
sub isNodeRegular {
    my $self = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    my $config = $self->getNodeConfig($node);
    return 0 unless defined($config) and not $config->{disabled};

    return $config->{regular} ? 1 : 0;
}

###############################################################################
# Get array of strings with names of observers that need to be run on particular node.
#
# Arguments:
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     array of strings with names of observers.
#
sub getNodeObservers {
    my $self = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    my $config = $self->getNodeConfig($node);
    return [] unless defined($config) and not $config->{disabled} and exists($config->{observers});

    return [ grep {$_} split(/\s*,\s*/, $config->{observers}) ];
}

###############################################################################
# Get array of strings with names of all observers listening to provided event name in current node.
#
# Arguments:
#     event - string event name, i.e. 'create', 'finish', etc.
# Returns:
#     array of strings with names of all observers listening to provided event name in current node.
#
sub getObserversForEvent {
    my $self = shift;
    my $event = shift;

    $self->{eventObservers} ||= {};
    if (exists($self->{eventObservers}->{$event})) {
        return $self->{eventObservers}->{$event};
    }

    my $observers = [];
    foreach my $observer (@{$self->getAllObservers()}) {
        my $config = $self->getObserverConfig($observer);

        if (not exists($config->{events}) or $config->{events} eq 'all' or
            grep {$_ eq $event} split(/\s*,\s*/, $config->{events})
        ) {
            if (not exists($config->{nodes}) or $config->{nodes} eq 'all' or
                grep {$_ eq $self->node} split(/\s*,\s*/, $config->{nodes})
            ) {
                push @$observers, $observer;
            }
        }
    }

    $self->{eventObservers}->{$event} = $observers;
    return $observers;
}

###############################################################################
# Get array of strings with names of workers that need to be run as daemons on particular node.
#
# Arguments:
#     node - optional string node name. If undefined, current node will be used.
# Returns:
#     array of strings with names of workers.
#
sub getNodeWorkers {
    my $self = shift;
    my $node = shift;

    unless (defined($node)) {
        $node = $self->node;
    }

    my $config = $self->getNodeConfig($node);
    return [] unless defined($config) and not $config->{disabled} and exists($config->{workers});

    return [ grep {$_} split(/\s*,\s*/, $config->{workers}) ];
}

###############################################################################
# Get array of hashes with detailed information abount job properties.
# All possible fields in that hashes see in documentation.
# Each hash here has 'access' field which contains instance of AnyJob::Access::Resource class.
# It signifies access needed to set this property.
#
# Returns:
#     array of hashes with detailed properties information.
#
sub getProps {
    my $self = shift;

    if (exists($self->{props})) {
        return $self->{props};
    }

    $self->{props} = [];

    my $config = $self->section('creator') || {};
    unless (defined($config->{props})) {
        return [];
    }

    my $props;
    eval {
        $props = $self->parseParams($config->{props});
    };
    if ($@) {
        require Carp;
        Carp::confess('Wrong props: ' . $config->{props});
    }

    $self->{props} = $props;
    return $props;
}

###############################################################################
# Get hash with access groups. Each element of that hash is an array with accesses and groups.
# Details see in documentation.
#
# Returns:
#     hash with access groups information.
#
sub getAccessGroups {
    my $self = shift;

    if (exists($self->{accessGroups})) {
        return $self->{accessGroups};
    }

    $self->{accessGroups} = {};

    my $config = $self->section('creator') || {};
    unless (exists($config->{access_groups})) {
        return {};
    }

    my $accessGroups;
    eval {
        $accessGroups = decode_json($config->{access_groups});
    };
    if ($@ or ref($accessGroups) ne 'HASH') {
        require Carp;
        Carp::confess('Wrong access groups: ' . $config->{access_groups});
    }

    foreach my $accesses (values(%$accessGroups)) {
        unless (ref($accesses) eq 'ARRAY') {
            require Carp;
            Carp::confess('Wrong access groups: ' . $config->{access_groups});
        }
    }

    $self->{accessGroups} = $accessGroups;
    return $accessGroups;
}

###############################################################################
# Get hash with delay operations accesses. Each key in that hash is action name and value is according access.
# Details see in documentation.
#
# Returns:
#     hash with delay operations accesses.
#
sub getDelayAccess {
    my $self = shift;

    if (exists($self->{delayAccess})) {
        return $self->{delayAccess};
    }

    my $delayAccess = {};

    my $config = $self->section('creator') || {};
    if (exists($config->{delay_access})) {
        eval {
            $delayAccess = decode_json($config->{delay_access});
        };
        if ($@ or ref($delayAccess) ne 'HASH') {
            require Carp;
            Carp::confess('Wrong delay access: ' . $config->{delay_access});
        }
    }

    $self->{delayAccess} = {};

    foreach my $action (keys(%$delayAccess)) {
        if (exists(DELAY_REAL_ACTIONS()->{$action})) {
            $self->{delayAccess}->{$action} = AnyJob::Access::Resource->new(input => $delayAccess->{$action});
        }
    }

    return $self->{delayAccess};
}

###############################################################################
# Get path to templates used primarily by observers and creators (for private observers).
#
# Returns:
#     string path to templates.
#
sub getTemplatesPath {
    my $self = shift;
    return injectPathIntoConstant($self->templates_path || DEFAULT_TEMPLATES_PATH);
}

###############################################################################
# Parse array of hashes with detailed information about parameters.
# All possible fields in that hashes see in documentation.
# Each hash here has 'access' field which contains instance of AnyJob::Access::Resource class.
# It signifies access needed to set this parameter.
#
# Arguments:
#     params - string with parameters array in JSON format.
# Returns:
#     array of hashes with detailed parameters information.
#
sub parseParams {
    my $self = shift;
    my $params = shift;

    utf8::encode($params);

    eval {
        $params = decode_json($params);
    };
    if ($@ or ref($params) ne 'ARRAY') {
        require Carp;
        Carp::confess('Wrong params');
    }

    foreach my $param (@$params) {
        if (exists($param->{access}) and $param->{access} ne '') {
            $param->{access} = AnyJob::Access::Resource->new(input => $param->{access});
        } else {
            $param->{access} = $AnyJob::Access::Resource::ACCESS_ANY;
        }
    }

    return $params;
}

###############################################################################
# Parse hash with detailed information about semaphores guarding some entity.
# {
#    '<mode>' => [ { 'name': '<name>', 'client': '<client>', 'cmode': '<clientMode>' }, ... ],
#    ...
# }
# '<mode>' here is one of predefined semaphore mode names for entity, '<name>' is one of configured semaphore names,
# '<client>' is arbitrary client name (it is optional, string with entity type will be used by default) and
# '<clientMode>' is optional client mode ('entity', 'jobset' or 'single'). When client mode is not specified, some
# default value will be used depending on mode.
#
# Arguments:
#     semaphores - string with semaphores configuration in JSON format.
# Returns:
#     hash with semaphores configuration.
#
sub parseSemaphores {
    my $self = shift;
    my $semaphores = shift;

    eval {
        $semaphores = decode_json($semaphores);
    };
    if ($@ or ref($semaphores) ne 'HASH') {
        require Carp;
        Carp::confess('Wrong semaphores');
    }

    foreach my $mode (keys(%$semaphores)) {
        if (ref($semaphores->{$mode}) ne 'ARRAY') {
            $semaphores->{$mode} = [ $semaphores->{$mode} ];
        }
        $semaphores->{$mode} = [ map {ref($_) eq 'HASH' ? $_ : { name => $_ }} @{$semaphores->{$mode}} ];
    }

    return $semaphores;
}

1;
