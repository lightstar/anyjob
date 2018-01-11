package AnyJob::Config;

###############################################################################
# Configuration class used to collect, store and retrieve configuration data.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  10.01.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;
use File::Spec;

use AnyJob::Constants::Defaults qw(
    DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_OBSERVERS_CONFIG_PATH DEFAULT_CREATORS_CONFIG_PATH
    DEFAULT_BUILDERS_CONFIG_PATH DEFAULT_WORKER_WORK_DIR DEFAULT_WORKER_EXEC DEFAULT_TEMPLATES_PATH
    DEFAULT_INTERNAL_PROPS injectPathIntoConstant
    );

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
    my $baseDir = dirname($fileName);

    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->nodes_path || DEFAULT_NODES_CONFIG_PATH)),
        'node');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->jobs_path || DEFAULT_JOBS_CONFIG_PATH)),
        'job');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->observers_path || DEFAULT_OBSERVERS_CONFIG_PATH)),
        'observer');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->creators_path || DEFAULT_CREATORS_CONFIG_PATH)),
        'creator');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->builders_path || DEFAULT_BUILDERS_CONFIG_PATH)),
        'builder');

    return $self;
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
#
# Returns:
#     array of hashes with detailed information about all available jobs:
#     [{
#         type => '...',
#         nodes => {
#             available => [ 'node1', 'node2', node3', ... ],
#             default   => { 'node1' => 1, 'node2' => 1, ... }
#         },
#         label => '...',
#         group => '...',
#         params => { 'param1': '...', 'param2': '...', ... }
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

            push @jobs, {
                    type   => $type,
                    nodes  => {
                        available => $nodes,
                        default   => { map {$_ => 1} split(/\s*,\s*/, $self->{data}->{$section}->{defaultNodes} || '') }
                    },
                    label  => $self->{data}->{$section}->{label} || $type,
                    group  => $self->{data}->{$section}->{group} || '',
                    params => $self->getJobParams($type),
                    sort   => $self->{data}->{$section}->{sort} || 0
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
# Get array of hashes with detailed information about parameters for given job type.
# All possible fields in that hashes see in documentation.
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
    unless (defined($config)) {
        return [];
    }

    my $params = $config->{params} || '[]';
    utf8::encode($params);

    eval {
        $params = decode_json($params);
    };
    if ($@) {
        return [];
    }

    unless (ref($params) eq 'ARRAY') {
        return [];
    }

    $self->{jobParams}->{$type} = $params;
    return $params;
}

###############################################################################
# Get job worker configuration data as multiple returned values.
#
# Arguments:
#     type - string job type.
# Returns:
#     string work directory for executable.
#     string executable name.
#     optional string additional libraries needed by worker executable (could be undef if there are none).
#
sub getJobWorker {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    my $workerSection = $self->section('worker') || {};

    return (
        injectPathIntoConstant($config->{work_dir} || $workerSection->{work_dir} || DEFAULT_WORKER_WORK_DIR),
        injectPathIntoConstant($config->{exec} || $workerSection->{exec} || DEFAULT_WORKER_EXEC),
        $config->{lib} || $workerSection->{lib}
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
#     type - string job type.
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
# Get array of hashes with detailed information abount job properties.
# All possible fields in that hashes see in documentation.
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

    my $props = $config->{props};
    utf8::encode($props);

    eval {
        $props = decode_json($props);
    };
    if ($@) {
        return [];
    }

    unless (ref($props) eq 'ARRAY') {
        return [];
    }

    $self->{props} = $props;
    return $props;
}

###############################################################################
# Get array of strings with names of internal job properties which are legal but can't be set by creator's clients,
# only by creator itself.
#
# Returns:
#     array of strings with names of properties.
#
sub getInternalProps {
    my $self = shift;

    if (exists($self->{internalProps})) {
        return $self->{internalProps};
    }

    $self->{internalProps} = [];

    my $config = $self->section('creator') || {};
    my $internalProps = defined($config->{internal_props}) ? $config->{internal_props} : DEFAULT_INTERNAL_PROPS;

    $self->{internalProps} = [ split(/\s*,\s*/, $internalProps) ];
    return $self->{internalProps};
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

1;
