package AnyJob::Creator::Parser;

###############################################################################
# Class used to parse text command-line into hash with job data which can be fed to creator's 'createJobs' method.
# If there are any errors or warnings in arguments, they are returned in very detailed form.
# Additionally command-line can contain some pre-defined extra arguments which are also returned as separate hash.
#
# Command-line must have this structure:
# <job type> [arg1] [arg2] [arg3] ...
# So the first argument is always job type and others may be any of:
#   - job parameter in form '<name>=<value>'.
#   - job property in form '<name>=<value>'.
#   - nodes in form 'nodes=<list of nodes names separated by comma>'.
#   - implicit nodes in form '<list of nodes names separated by comma>'.
#   - extra parameters included in 'allowedExtra' in form '<name>=<value>'.
#   - implicit parameters in form '<value>'. According parameter must be configured as implicit.
#   - implicit properties in form '<value>'. According property must be configured as implicit.
# All possibilities are checked by parsing in exactly that order. Unrecognized arguments will produce errors.
# You are free to use quotes and escapes here like in any shell command-line.
#
# If some parameter, property or nodes are missing, then configured default values will be used if any,
# and appropriate warning will be included in 'errors' array.
#
# Author:       LightStar
# Created:      23.11.2017
# Last update:  27.02.2018
#

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);

###############################################################################
# Construct new AnyJob::Creator::Parser object.
#
# Arguments:
#     parent       - parent component which is usually AnyJob::Creator object.
#     input        - input command-line as raw string text or already parsed array of arguments.
#     allowedExtra - array of strings with allowed additional params in command-line which will be returned in
#                    separate hash after parsing.
# Returns:
#     AnyJob::Creator::Parser object.
#
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

###############################################################################
# Returns:
#     parent component which is usually AnyJob::Creator object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{parent}->config;
}

###############################################################################
# Returns:
#     hash with parsed job data as described in creator's 'createJobs' method. Initially it will be undef.
#     May be incomplete in case of errors, so check them first.
#
sub job {
    my $self = shift;
    return $self->{job};
}

###############################################################################
# Returns:
#     array of hashes with errors or warnings data. Initially it will be empty.
#     Each hash has following structure:
#     {
#         type => '...',
#         arg => '...',
#         field => '...',
#         param => '...',
#         value => '...',
#         text => '...'
#     }
#     Field 'type' is always here and have string value 'error' or 'warning'. 'error' means that command-line included
#     some arguments or values that shouldn't be here and job can't be created. The same is with not-included required
#     parameters. And 'warning' usually means that command-line missed some parameters or nodes, and default values
#     were used.
#     Field 'arg' is included if error related to the whole argument, and contains its value.
#     Field 'field' is included if error related to some field of job data, and contains its name.
#     Field 'param' is included if error related to some specific parameter or property in job data,
#     and contains its name.
#     Field 'value' is included if error related to some value of job field or parameter in job data,
#     and contains it.
#     Field 'text' is always here and contains detailed error or warning description.
#
sub errors {
    my $self = shift;
    return $self->{errors};
}

###############################################################################
# Returns:
#     hash with parsed additional parameters specified in 'allowedExtra' constructor parameter.
#     Initially it will be undef.
#     For example, if 'allowedExtra' is ['param1','param2','param3'], then result may be something as
#     { 'param1' => '...', 'param2' => '...' }
#     Only parameters really present in command-line will be included.
#
sub extra {
    my $self = shift;
    return $self->{extra};
}

###############################################################################
# Prepare parsing. Check for basic correctness of command-line here and generate helper data structures.
#
# Returns:
#     1/undef on success/error accordingly. In case of error further parsing is pointless and 'errors' will return
#     array with errors. Otherwise you may proceed with 'parse' method.
#
sub prepare {
    my $self = shift;

    if (ref($self->{input}) eq 'ARRAY') {
        $self->{args} = $self->{input};
    } else {
        $self->{args} = [ parse_line('\s+', 0, $self->{input}) ];
    }

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

###############################################################################
# Parse command-line. Must be called after 'prepare' method.
# After this method is finished, you may call 'job', 'extra' and 'errors' methods to fetch results.
#
sub parse {
    my $self = shift;

    foreach my $arg (@{$self->{args}}) {
        my ($name, $value) = ($arg =~ /^([^=]+)(?:\=(.+))?$/);

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
            $self->processImplicitParamArg($name, $value) or
            $self->processImplicitPropArg($name, $value) or
            $self->processUnknownArg($name);
    }

    $self->injectDefaultNodes();
    $self->injectDefaultParams();
    $self->injectDefaultProps();
}

###############################################################################
# Check if current argument is job parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not job parameter at all, and
#     on success it is, but not necessarily correct one.
#
sub processParamArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $param = $self->{params}->{$name})) {
        if ($param->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkJobParamType($param->{type}, $value, $param->{options})) {
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

###############################################################################
# Check if current argument is job property and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not job property at all, and
#     on success it is, but not necessarily correct one.
#
sub processPropArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $prop = $self->{props}->{$name})) {
        if ($prop->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkJobParamType($prop->{type}, $value, $prop->{options})) {
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

###############################################################################
# Check if current argument is 'nodes' parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not 'nodes' parameter, and
#     on success it is, but not necessarily have correct value.
#
sub processNodesArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if ($name ne 'nodes') {
        return undef;
    }

    unless (defined($value) and $value ne '') {
        push @{$self->{errors}}, {
                type  => 'error',
                field => 'nodes',
                text  => '\'nodes\' arg without value'
            };
        return 1;
    }

    my @nodes = split(/\s*,\s*/, $value);
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

###############################################################################
# Check if current argument is implicit nodes and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not implicit nodes, and
#     on success it is.
#
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

###############################################################################
# Check if current argument is extra parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not extra parameter, and
#     on success it is.
#
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

###############################################################################
# Check if current argument is implicit parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not implicit parameter, and
#     on success it is.
#
sub processImplicitParamArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined($value)) {
        return undef;
    }

    foreach my $param (grep {$_->{implicit}} @{$self->config->getJobParams($self->job->{type})}) {
        if ($self->parent->checkJobParamType($param->{type}, $name, $param->{options})) {
            $self->job->{params}->{$param->{name}} = $name;
            return 1;
        }
    }

    return undef;
}

###############################################################################
# Check if current argument is implicit property and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not implicit property, and
#     on success it is.
#
sub processImplicitPropArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined($value)) {
        return undef;
    }

    foreach my $prop (grep {$_->{implicit}} @{$self->config->getProps()}) {
        if ($self->parent->checkJobParamType($prop->{type}, $name, $prop->{options})) {
            $self->job->{props}->{$prop->{name}} = $name;
            return 1;
        }
    }

    return undef;
}

###############################################################################
# Process any unknown argument. Generate an error in that case.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value.
# Returns:
#     always 1.
#
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

###############################################################################
# Inject default nodes into job data if there are no nodes in it yet.
# Generate error in case of empty nodes.
#
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

###############################################################################
# Inject default parameter values into job data for yet non-existent parameters.
# Generate error in case of missing required parameters.
#
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

###############################################################################
# Inject default property values into job data for yet non-existent properties.
# Generate error in case of missing required properties.
#
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
