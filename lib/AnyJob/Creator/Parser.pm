package AnyJob::Creator::Parser;

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{input})) {
        require Carp;
        Carp::confess('No input provided');
    }

    $self->{allowedExtra} ||= {};
    $self->{errors} = [];

    return $self;
}

sub parent {
    my $self = shift;
    return $self->{parent};
}

sub config {
    my $self = shift;
    return $self->{parent}->config;
}

sub job {
    my $self = shift;
    return $self->{job};
}

sub errors {
    my $self = shift;
    return $self->{errors};
}

sub extra {
    my $self = shift;
    return $self->{extra};
}

sub prepare {
    my $self = shift;

    $self->{args} = [ parse_line('\s+', 0, $self->{input}) ];
    unless (scalar(@{$self->{args}}) > 0) {
        push @{$self->{errors}}, {
                type  => 'error',
                field => 'type',
                text  => 'no job type'
            };
        return undef;
    }

    my $type = shift(@{$self->{args}});

    $self->{jobConfig} = $self->config->getJobConfig($type);
    unless (defined($self->{jobConfig})) {
        push @{$self->{errors}}, {
                type  => 'error',
                field => 'type',
                value => $type,
                text  => 'unknown job type \'' . $type . '\''
            };
        return undef;
    }

    $self->{job} = {
        type   => $type,
        nodes  => [],
        params => {},
        props  => {}
    };

    $self->{extra} = {};

    $self->{params} = { map {$_->{name} => $_} @{$self->config->getJobParams($type)} };
    $self->{props} = { map {$_->{name} => $_} @{$self->config->getProps()} };
    $self->{nodes} = { map {$_ => 1} @{$self->config->getJobNodes($type)} };

    return 1;
}

sub parse {
    my $self = shift;

    foreach my $arg (@{$self->{args}}) {
        my ($name, $value) = split(/=/, $arg);

        if ($name eq '') {
            next;
        }

        if (exists($self->{processedArgs}->{$name})) {
            push @{$self->{errors}}, {
                    type => 'error',
                    arg  => $name,
                    text => 'duplicate arg \'' . $name . '\''
                };
            next;
        }

        $self->{processedArgs}->{$name} = 1;

        $self->processParamArg($name, $value) or
            $self->processPropArg($name, $value) or
            $self->processNodesArg($name, $value) or
            $self->processImplicitNodesArg($name, $value) or
            $self->processExtraArg($name, $value) or
            $self->processUnknownArg($name);
    }

    $self->injectDefaultNodes();
    $self->injectDefaultParams();
    $self->injectDefaultProps();
}

sub processParamArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $param = $self->{params}->{$name})) {
        if ($param->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkParamType($param->{type}, $value, $param->{data})) {
            push @{$self->{errors}}, {
                    type  => 'error',
                    field => 'params',
                    param => $name,
                    value => $value,
                    text  => 'wrong param \'' . $name . '\' = \'' . $value . '\''
                };
        } else {
            $self->job->{params}->{$name} = $value;
        }

        return 1;
    }

    return undef;
}

sub processPropArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $prop = $self->{props}->{$name})) {
        if ($prop->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkParamType($prop->{type}, $value, $prop->{data})) {
            push @{$self->{errors}}, {
                    type  => 'error',
                    field => 'props',
                    param => $name,
                    value => $value,
                    text  => 'wrong prop \'' . $name . '\' = \'' . $value . '\''
                };
        } else {
            $self->job->{props}->{$name} = $value;
        }

        return 1;
    }

    return undef;
}

sub processNodesArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if ($name ne 'nodes' or not defined($value)) {
        return undef;
    }

    my @nodes = split(/\s*,\s*/, $value);
    if (scalar(@nodes) == 0) {
        push @{$self->{errors}}, {
                type  => 'error',
                field => 'nodes',
                text  => '\'nodes\' arg without value'
            };
        return 1;
    }

    my $isAllValid = 1;
    foreach my $node (@nodes) {
        unless (exists($self->{nodes}->{$node})) {
            $isAllValid = 0;
            push @{$self->{errors}}, {
                    type  => 'error',
                    field => 'nodes',
                    value => $node,
                    text  => 'not supported node \'' . $node . '\''
                };
        }
    }

    if ($isAllValid) {
        $self->job->{nodes} = \@nodes;
    }

    return 1;
}

sub processImplicitNodesArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined($value)) {
        return undef;
    }

    my @nodes = split(/\s*,\s*/, $name);
    foreach my $node (@nodes) {
        unless (exists($self->{nodes}->{$node})) {
            return undef;
        }
    }

    $self->job->{nodes} = \@nodes;
    return 1;
}

sub processExtraArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (exists($self->{allowedExtra}->{$name})) {
        $self->{extra}->{$name} = $value;
        return 1;
    }

    return undef;
}

sub processUnknownArg {
    my $self = shift;
    my $name = shift;

    push @{$self->{errors}}, {
            type => 'error',
            arg  => $name,
            text => 'wrong arg \'' . $name . '\''
        };

    return 1;
}

sub injectDefaultNodes {
    my $self = shift;

    if (defined($self->{jobConfig}->{defaultNodes}) and scalar(@{$self->job->{nodes}}) == 0) {
        $self->job->{nodes} = [
            grep {exists($self->{nodes}->{$_})}
                split(/\s*,\s*/, $self->{jobConfig}->{defaultNodes})
        ];

        if (scalar(@{$self->job->{nodes}}) > 0) {
            my $nodes = join(',', @{$self->job->{nodes}});
            push @{$self->{errors}}, {
                    type  => 'warning',
                    field => 'nodes',
                    value => $nodes,
                    text  => 'used default nodes \'' . $nodes . '\''
                };
        }
    }

    if (scalar(@{$self->job->{nodes}}) == 0) {
        push @{$self->{errors}}, {
                type  => 'error',
                field => 'nodes',
                text  => 'no nodes'
            };
    }
}

sub injectDefaultParams {
    my $self = shift;

    my $jobParams = $self->job->{params};

    foreach my $param (values(%{$self->{params}})) {
        my $name = $param->{name};
        if (exists($param->{default}) and $param->{default} ne '' and
            (not exists($jobParams->{$name}) or $jobParams->{$name} eq '')
        ) {
            $jobParams->{$name} = $param->{default};
            push @{$self->{errors}}, {
                    type  => 'warning',
                    field => 'params',
                    param => $name,
                    value => $jobParams->{$name},
                    text  => 'used default param value \'' . $name . '\' = \'' . $jobParams->{$name} . '\''
                };
        } elsif ($param->{required} and
            (not exists($jobParams->{$name}) or $jobParams->{$name} eq '')
        ) {
            push @{$self->{errors}}, {
                    type  => 'error',
                    field => 'params',
                    param => $name,
                    text  => 'no required param \'' . $name . '\''
                };
        }
    }
}

sub injectDefaultProps {
    my $self = shift;

    my $jobProps = $self->job->{props};

    foreach my $prop (values(%{$self->{props}})) {
        my $name = $prop->{name};
        if (exists($prop->{default}) and $prop->{default} ne '' and
            (not exists($jobProps->{$name}) or $jobProps->{$name} eq '')
        ) {
            $jobProps->{$name} = $prop->{default};
            push @{$self->{errors}}, {
                    type  => 'warning',
                    field => 'props',
                    param => $name,
                    value => $jobProps->{$name},
                    text  => 'used default prop value \'' . $name . '\' = \'' . $jobProps->{$name} . '\''
                };
        } elsif ($prop->{required} and
            (not exists($jobProps->{$name}) or $jobProps->{$name} eq '')
        ) {
            push @{$self->{errors}}, {
                    type  => 'error',
                    field => 'props',
                    param => $name,
                    text  => 'no required prop \'' . $name . '\''
                };
        }
    }
}

1;
