package AnyJob::Config;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;
use File::Spec;

use AnyJob::Constants::Defaults qw(
    DEFAULT_NODES_CONFIG_DIR DEFAULT_JOBS_CONFIG_DIR DEFAULT_OBSERVERS_CONFIG_DIR DEFAULT_BUILDS_CONFIG_DIR
    DEFAULT_WORKER_WORK_DIR DEFAULT_WORKER_EXEC DEFAULT_TEMPLATES_PATH DEFAULT_INTERNAL_PROPS
    injectPathIntoConstant
    );

use base 'AnyJob::Config::Base';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $fileName = shift;
    my $baseDir = dirname($fileName);

    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->nodes_dir || DEFAULT_NODES_CONFIG_DIR)),
        'node');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->jobs_dir || DEFAULT_JOBS_CONFIG_DIR)),
        'job');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->observers_dir || DEFAULT_OBSERVERS_CONFIG_DIR)),
        'observer');
    $self->addConfigFromDir(File::Spec->catdir($baseDir, ($self->builders_dir || DEFAULT_BUILDS_CONFIG_DIR)),
        'builder');

    return $self;
}

sub node {
    my $self = shift;

    if (exists($self->{node})) {
        return $self->{node};
    }

    $self->{node} = $ENV{ANYJOB_NODE} || '';
    return $self->{node};
}

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

sub getJobConfig {
    my $self = shift;
    my $type = shift;
    return $self->section('job_' . $type);
}

sub getNodeConfig {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;
    return $self->section('node_' . $node);
}

sub getObserverConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('observer_' . $name);
}

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

sub getJobWorker {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    my $workerSection = $self->section('worker') || {};

    return ($config->{work_dir} || $workerSection->{work_dir} || injectPathIntoConstant(DEFAULT_WORKER_WORK_DIR),
        $config->{exec} || $workerSection->{exec} || injectPathIntoConstant(DEFAULT_WORKER_EXEC),
        $config->{lib} || $workerSection->{lib});
}

sub isJobSupported {
    my $self = shift;
    my $type = shift;
    my $node = shift;
    $node ||= $self->node;

    if (exists($self->{jobSupported}->{$node}->{$type})) {
        return $self->{jobSupported}->{$node}->{$type};
    }

    my $result;
    my $jobConfig = $self->getJobConfig($type);
    my $nodeConfig = $self->getNodeConfig($node);

    if (not defined($jobConfig) or $jobConfig->{disabled}) {
        $result = 0;
    } elsif (not defined($nodeConfig) or $nodeConfig->{disabled}) {
        $result = 0;
    } elsif (not exists($jobConfig->{nodes}) or $jobConfig->{nodes} eq 'all') {
        my $except = $jobConfig->{except} || '';
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $except)) ? 0 : 1;
    } else {
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $jobConfig->{nodes})) ? 0 : 1;
    }

    $self->{jobSupported}->{$node}->{$type} = $result;

    return $result;
}

sub isNodeGlobal {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;

    my $config = $self->getNodeConfig($node);
    return 0 unless defined($config) and not $config->{disabled};

    return $config->{global} ? 1 : 0;
}

sub isNodeRegular {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;

    my $config = $self->getNodeConfig($node);
    return 0 unless defined($config) and not $config->{disabled};

    return $config->{regular} ? 1 : 0;
}

sub getNodeObservers {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;

    my $config = $self->getNodeConfig($node);
    return [] unless defined($config) and not $config->{disabled} and exists($config->{observers});

    return [ grep {$_} split(/\s*,\s*/, $config->{observers}) ];
}

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

sub getBuilderConfig {
    my $self = shift;
    my $name = shift;
    return $self->section('builder_' . $name);
}

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

sub getTemplatesPath {
    my $self = shift;
    return $self->templates_path || injectPathIntoConstant(DEFAULT_TEMPLATES_PATH);
}

1;
