package AnyJob::Creator::Parser::Job;

###############################################################################
# Class used to parse text command-line into hash with job data which can be fed to creator's 'createJobs' or
# 'delayJobs' methods. If there are any errors or warnings in arguments, they are returned in very detailed form.
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
# Created:      29.05.2018
# Last update:  30.01.2019
#

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);

###############################################################################
# Construct new AnyJob::Creator::Parser::Job object.
#
# Arguments:
#     parent       - parent component which is usually AnyJob::Creator object.
#     input        - input command-line as raw string text.
#     args         - already parsed array of string arguments (alternative to 'input').
#     allowedExtra - array of strings with allowed additional params in command-line which will be returned in
#                    separate hash after parsing.
# Returns:
#     AnyJob::Creator::Parser::Job object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{args})) {
        unless (defined($self->{input})) {
            require Carp;
            Carp::confess('No args or input provided');
        }
        $self->{args} = [ parse_line('\s+', 0, $self->{input}) ];
    }

    $self->{allowedExtra} ||= {};
    $self->{errors} = [];
    $self->{job} = undef;
    $self->{extra} = undef;

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

    unless (scalar(@{$self->{args}}) > 0) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => 'type',
            text  => 'no job type'
        };
        return undef;
    }

    my $type = shift(@{$self->{args}});
    my $config = $self->config->getJobConfig($type);
    unless (defined($config)) {
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

    $self->{params} = $self->config->getJobParams($type);
    $self->{paramsHash} = { map {$_->{name} => $_} @{$self->{params}} };

    $self->{props} = $self->config->getJobProps($type);
    unless (defined($self->{props})) {
        $self->{props} = $self->config->getProps();
    }
    $self->{propsHash} = { map {$_->{name} => $_} @{$self->{props}} };

    $self->{nodes} = { map {$_ => 1} @{$self->config->getJobNodes($type)} };
    $self->{defaultNodes} = $config->{default_nodes};
    $self->{minNodes} = $config->{min_nodes} || 0;
    $self->{maxNodes} = $config->{max_nodes} || 0;

    return 1;
}

###############################################################################
# Parse command-line. Must be called after 'prepare' method.
# After this method is finished, you may call 'job', 'extra' and 'errors' methods to fetch results.
#
sub parse {
    my $self = shift;

    while (my $arg = shift(@{$self->{args}})) {
        my ($name, $value) = ($arg =~ /^([^=]+)(?:\=(.+))?$/);

        unless (defined($name) and $name ne '') {
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
    $self->checkNodesCount();
}

###############################################################################
# Check if current argument is job parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value or undef.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not job parameter at all, and
#     on success it is, but not necessarily correct one.
#
sub processParamArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $param = $self->{paramsHash}->{$name})) {
        if ($param->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkJobParamType($param->{type}, $value, $param->{options})) {
            push @{$self->{errors}}, {
                type  => 'error',
                field => 'params',
                param => $name,
                value => $value,
                text  => 'wrong param \'' . $name . '\' = ' . (defined($value) ? '\'' . $value . '\'' : '<undef>')
            };
        } else {
            $self->{job}->{params}->{$name} = $value;
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
#     value - string parameter value or undef.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not job property at all, and
#     on success it is, but not necessarily correct one.
#
sub processPropArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined(my $prop = $self->{propsHash}->{$name})) {
        if ($prop->{type} eq 'flag' and not defined($value)) {
            $value = 1;
        }

        unless ($self->parent->checkJobParamType($prop->{type}, $value, $prop->{options})) {
            push @{$self->{errors}}, {
                type  => 'error',
                field => 'props',
                param => $name,
                value => $value,
                text  => 'wrong prop \'' . $name . '\' = ' . (defined($value) ? '\'' . $value . '\'' : '<undef>')
            };
        } else {
            $self->{job}->{props}->{$name} = $value;
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
#     value - string parameter value or undef.
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
        $self->{job}->{nodes} = \@nodes;
    }

    return 1;
}

###############################################################################
# Check if current argument is implicit nodes and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value or undef.
# Returns:
#     1/undef on success/error accordingly. In case of error current argument is not implicit nodes, and
#     on success it is.
#
sub processImplicitNodesArg {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if (defined($value) or scalar(@{$self->{job}->{nodes}}) > 0) {
        return undef;
    }

    my @nodes = split(/\s*,\s*/, $name);
    foreach my $node (@nodes) {
        unless (exists($self->{nodes}->{$node})) {
            return undef;
        }
    }

    $self->{job}->{nodes} = \@nodes;
    return 1;
}

###############################################################################
# Check if current argument is extra parameter and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value or undef.
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
#     value - string parameter value or undef.
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

    foreach my $param (grep {$_->{implicit}} @{$self->{params}}) {
        unless (exists($self->{job}->{params}->{$param->{name}})) {
            if ($self->parent->checkJobParamType($param->{type}, $name, $param->{options})) {
                $self->{job}->{params}->{$param->{name}} = $name;
                return 1;
            }
        }
    }

    return undef;
}

###############################################################################
# Check if current argument is implicit property and parse it.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value or undef.
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

    foreach my $prop (grep {$_->{implicit}} @{$self->{props}}) {
        unless (exists($self->{job}->{props}->{$prop->{name}})) {
            if ($self->parent->checkJobParamType($prop->{type}, $name, $prop->{options})) {
                $self->{job}->{props}->{$prop->{name}} = $name;
                return 1;
            }
        }
    }

    return undef;
}

###############################################################################
# Process any unknown argument. Generate an error in that case.
#
# Arguments:
#     name  - string parameter name.
#     value - string parameter value or undef.
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

    if (defined($self->{defaultNodes}) and scalar(@{$self->{job}->{nodes}}) == 0) {
        $self->{job}->{nodes} = [
            grep {exists($self->{nodes}->{$_})}
                split(/\s*,\s*/, $self->{defaultNodes})
        ];

        if (scalar(@{$self->{job}->{nodes}}) > 0) {
            my $nodes = join(',', @{$self->{job}->{nodes}});
            push @{$self->{errors}}, {
                type  => 'warning',
                field => 'nodes',
                value => $nodes,
                text  => 'used default nodes \'' . $nodes . '\''
            };
        }
    }
}

###############################################################################
# Inject default parameter values into job data for yet non-existent parameters.
# Generate error in case of missing required parameters.
#
sub injectDefaultParams {
    my $self = shift;

    my $jobParams = $self->{job}->{params};

    foreach my $param (@{$self->{params}}) {
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

    my $jobProps = $self->{job}->{props};

    foreach my $prop (@{$self->{props}}) {
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

###############################################################################
# Check job nodes count and generate error in case it is invalid.
#
sub checkNodesCount {
    my $self = shift;

    if (scalar(@{$self->{job}->{nodes}}) == 0) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => 'nodes',
            text  => 'no nodes'
        };
    }

    if ($self->{minNodes} > 0 and scalar(@{$self->{job}->{nodes}}) < $self->{minNodes}) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => 'nodes',
            text  => 'too few nodes (minimum ' . $self->{minNodes} . ' required)'
        };
    }

    if ($self->{maxNodes} > 0 and scalar(@{$self->{job}->{nodes}}) > $self->{maxNodes}) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => 'nodes',
            text  => 'too many nodes (maximum ' . $self->{maxNodes} . ' allowed)'
        };
    }
}

1;
