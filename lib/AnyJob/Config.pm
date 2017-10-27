package AnyJob::Config;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Basename;
use File::Spec;

use base 'AnyJob::Config::Base';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $fileName = shift;
    my $baseDir = dirname($fileName);

    if (defined($self->nodes_dir)) {
        $self->addConfigFromDir(File::Spec->catdir($baseDir, $self->nodes_dir), 'node');
    }

    if (defined($self->jobs_dir)) {
        $self->addConfigFromDir(File::Spec->catdir($baseDir, $self->jobs_dir), 'job');
    }

    if (defined($self->observers_dir)) {
        $self->addConfigFromDir(File::Spec->catdir($baseDir, $self->observers_dir), 'observer');
    }

    return $self;
}

sub node {
    my $self = shift;

    if (exists($self->{node})) {
        return $self->{node};
    }

    $self->{node} = $ENV{ANYJOB_NODE} || "";
    return $self->{node};
}

sub addConfigFromDir {
    my $self = shift;
    my $dirName = shift;
    my $sectionPrefix = shift;

    my $dh;
    if (opendir($dh, $dirName)) {
        foreach my $fileName (readdir($dh)) {
            my $fullFileName = File::Spec->catfile($dirName, $fileName);
            next unless -f $fullFileName and $fileName !~ /^\./ and $fileName =~ /\.cfg$/;
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
                push @nodes, $node;
            }
        }
    }

    $self->{nodes} = \@nodes;

    return $self->{nodes};
}

sub getAllJobs {
    my $self = shift;

    if (exists($self->{jobs})) {
        return $self->{jobs};
    }

    my @jobs;
    foreach my $section (keys(%{$self->{data}})) {
        if (my ($job) = ($section =~ /^job_(.+)$/)) {
            unless ($self->{data}->{$section}->{disabled}) {
                push @jobs, $job;
            }
        }
    }

    $self->{jobs} = \@jobs;

    return $self->{jobs};
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

    return $self->{observers};
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

        if (not exists($config->{events}) or $config->{events} eq "all" or
            grep {$_ eq $event} split(/\s*,\s*/, $config->{events})
        ) {
            if (not exists($config->{nodes}) or $config->{nodes} eq "all" or
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
    return $self->section("job_" . $type);
}

sub getNodeConfig {
    my $self = shift;
    my $node = shift;
    $node ||= $self->node;
    return $self->section("node_" . $node);
}

sub getObserverConfig {
    my $self = shift;
    my $name = shift;
    return $self->section("observer_" . $name);
}

sub getJobParams {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    return decode_json($config->{params});
}

sub getJobWorker {
    my $self = shift;
    my $type = shift;

    my $config = $self->getJobConfig($type);
    return undef unless defined($config);

    my $workerSection = $self->section("worker") || {};

    return ($config->{work_dir} || $workerSection->{work_dir},
        $config->{exec} || $workerSection->{exec},
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

    my $config = $self->getJobConfig($type);
    unless (defined($config) and not $config->{disabled}) {
        $result = 0;
    } elsif (not exists($config->{nodes}) or $config->{nodes} eq "all") {
        my $except = $config->{except} || "";
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $except)) ? 0 : 1;
    } else {
        $result = (grep {$_ eq $node} split(/\s*,\s*/, $config->{nodes})) ? 0 : 1;
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

1;
