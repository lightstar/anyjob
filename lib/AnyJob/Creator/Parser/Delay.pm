package AnyJob::Creator::Parser::Delay;

###############################################################################
# Class used to parse text command-line into hash with delay data which can be fed to different creator's
# methods like 'delayJobs'. If there are any errors in arguments, they are returned in very detailed form.
#
# Command-line can be one of these variants:
# <time>
# update <id> <time>
# delete <id>
# get [id]
#
# First variant will create delay data with 'create' action, while in others action name is specified explicitly.
# First two variants will require additional job data which should be parsed by some other parser
# (such as AnyJob::Creator::Parser::Job).
#
# Parameter 'time' here is string with date and time in any format supported by AnyJob::DateTime::parseDateTime method.
# Parameter 'id' is integer id of already created delayed object.
#
# Author:       LightStar
# Created:      29.05.2018
# Last update:  22.06.2018
#

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);

use AnyJob::Constants::Delay;
use AnyJob::DateTime qw(parseDateTime);

###############################################################################
# Construct new AnyJob::Creator::Parser::Delay object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
#     input  - input command-line as raw string text.
#     args   - already parsed array of string arguments (alternative to 'input').
#
# Returns:
#     AnyJob::Creator::Parser::Delay object.
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

    $self->{errors} = [];
    $self->{delay} = undef;

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
#     hash with parsed delay data. Initially it will be undef. May be incomplete in case of errors, so check them first.
#     Format of that hash is the following:
#     {
#         action => '...',
#         id => ...,
#         time => ...,
#         create => { input => '...' }
#     }
#     Field 'action' here is one of strings identifying action which needs to be performed on delayed object: 'create',
#     'update', 'delete' or 'get'.
#     Field 'id' here is present only for 'update' and 'delete' actions, and could optionally exist for 'get' action.
#     It is integer id of delayed object.
#     Field 'time' here is present only for 'create' and 'update' actions. It is integer time in unix timestamp format.
#     Field 'create' here is present only for 'create' and 'update' actions. Its inner 'input' field contains all
#     remained parameters, escaped and joined using space character.
#
sub delay {
    my $self = shift;
    return $self->{delay};
}

###############################################################################
# Returns:
#     array of hashes with errors data. Initially it will be empty.
#     Each hash has following structure:
#     {
#         type => '...',
#         field => '...',
#         text => '...'
#     }
#     Field 'type' is always 'error' here which means that delay data couldn't be parsed.
#     Field 'field' is always '@delay' here.
#     Field 'text' is always here and contains detailed error description.
#
sub errors {
    my $self = shift;
    return $self->{errors};
}

###############################################################################
# Returns:
#     array of strings with args remained after parsing. Initially it will be equal to args given to constructor.
#     Caller can use them to parse any job data placed in the same command-line after delay data.
#
sub args {
    my $self = shift;
    return $self->{args};
}

###############################################################################
# Parse command-line.
# After this method is finished, you may call 'delay', 'args' and 'errors' methods to fetch results.
#
sub parse {
    my $self = shift;

    if (scalar(@{$self->{args}}) == 0) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => '@delay',
            text  => 'no delay data'
        };
        return;
    }

    my $action = $self->parseDelayAction();
    if ($action eq DELAY_ACTION_CREATE) {
        $self->processCreateAction();
    } elsif ($action eq DELAY_ACTION_UPDATE) {
        $self->processUpdateAction();
    } elsif ($action eq DELAY_ACTION_DELETE) {
        $self->processDeleteAction();
    } elsif ($action eq DELAY_ACTION_GET) {
        $self->processGetAction();
    }

    if (scalar(@{$self->{errors}}) == 0) {
        $self->injectCreateData();
    }
}

###############################################################################
# Parse parameters of 'create delayed' action.
#
sub processCreateAction {
    my $self = shift;

    if (defined(my $time = $self->parseDelayTime())) {
        $self->{delay} = {
            action => DELAY_ACTION_CREATE,
            create => {},
            time   => $time
        };
    }
}

###############################################################################
# Parse parameters of 'update delayed' action.
#
sub processUpdateAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId()) and defined(my $time = $self->parseDelayTime())) {
        $self->{delay} = {
            action => DELAY_ACTION_UPDATE,
            create => {},
            id     => $id,
            time   => $time
        };
    }
}

###############################################################################
# Parse parameters of 'delete delayed' action.
#
sub processDeleteAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        $self->{delay} = {
            action => DELAY_ACTION_DELETE,
            id     => $id
        };
    }
}

###############################################################################
# Parse parameters of 'get delayed' action.
#
sub processGetAction {
    my $self = shift;

    my $id = $self->parseDelayId(1);
    $self->{delay} = {
        action => DELAY_ACTION_GET,
        (defined($id) ? (id => $id) : ())
    }
}

###############################################################################
# Inject create data into hash with parsed delay data if needed to.
#
sub injectCreateData {
    my $self = shift;

    if (defined($self->{delay}->{create})) {
        my @args;
        foreach my $arg (@{$self->{args}}) {
            if ($arg =~ /[\s\'\"]/) {
                $arg =~ s/\'/\\\'/g;
                $arg = '\'' . $arg . '\'';
            }
            push @args, $arg;
        }
        $self->{delay}->{create}->{input} = join(' ', @args);
    }
}

###############################################################################
# Check if current argument is delay time and return it. Otherwise error is reported.
#
# Returns:
#     integer time in unix timestamp format or undef in case of error.
#
sub parseDelayTime {
    my $self = shift;

    my $dateTime = parseDateTime(shift(@{$self->{args}}));
    unless (defined($dateTime)) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => '@delay',
            text  => 'wrong delay time'
        };
        return undef;
    }

    return $dateTime->{unixTime};
}

###############################################################################
# Check if current argument is delay action and return it. Otherwise implicit delay action is returned
# (which is 'create').
#
# Returns:
#     string name of delay action.
#
sub parseDelayAction {
    my $self = shift;

    if (exists(DELAY_EXPLICIT_ACTIONS()->{$self->{args}->[0]})) {
        return shift(@{$self->{args}});
    }

    return DELAY_ACTION_CREATE;
}

###############################################################################
# Check if current argument is id of delayed object and return it. Otherwise error is reported.
#
# Returns:
#     integer id of delayed object or undef in case of error.
#
sub parseDelayId {
    my $self = shift;
    my $isOptional = shift;

    my $id = shift(@{$self->{args}});
    if (not defined($id) and $isOptional) {
        return undef;
    }

    unless (defined($id) and $id =~ /^\d+$/o) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => '@delay',
            text  => 'wrong delay id'
        };
        return undef;
    }

    return $id;
}

1;
