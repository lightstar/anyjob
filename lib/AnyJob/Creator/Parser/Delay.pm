package AnyJob::Creator::Parser::Delay;

###############################################################################
# Class used to parse text command-line into hash with delay data which can be fed to different creator's
# methods like 'delayJobs'. If there are any errors in arguments, they are returned in very detailed form.
#
# Command-line can be one of these variants:
# <time/crontab> [@skip <count>] [@paused]
# update <id>
# schedule <id> <time/crontab> [@skip <count>] [@paused]
# skip <id> <count>
# pause <id>
# resume <id>
# delete <id>
# get [id]
#
# First variant will create delay data with 'create' action, while in others action name is specified explicitly.
# First two variants will require additional job data which should be parsed by some other parser
# (such as AnyJob::Creator::Parser::Job).
#
# Parameter 'time' here is string with date and time in any format supported by AnyJob::DateTime::parseDateTime method.
# Parameter 'crontab' here is crontab specification string in format supported by AnyJob::Crontab::Scheduler module.
# Parameter 'id' is integer id of already created delayed work.
#
# Author:       LightStar
# Created:      29.05.2018
# Last update:  29.01.2019
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
#         summary => '',
#         time => ...
#     }
#     Field 'action' here is one of strings identifying action which needs to be performed on delayed work: 'create',
#     'update', 'delete' or 'get'.
#     Field 'id' here is present only for 'update' and 'delete' actions, and could optionally exist for 'get' action.
#     It is integer id of delayed work.
#     Field 'time' here is present only for 'create' and 'update' actions. It is integer time in unix timestamp format.
#     Field 'summary' here is present only for 'create' and 'update' actions. It contains all remained parameters,
#     escaped and joined using space character.
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
    my $methodName = 'process' . ucfirst($action) . 'Action';
    if ($self->can($methodName)) {
        $self->$methodName();
    }

    if (scalar(@{$self->{errors}}) == 0) {
        $self->generateSummary();
    }
}

###############################################################################
# Normalize delay action. After that delay action will be set to supported by delay controller one.
#
sub normalizeAction {
    my $self = shift;

    if (exists(DELAY_META_ACTIONS()->{$self->{delay}->{action}})) {
        $self->{delay}->{action} = DELAY_META_ACTIONS()->{$self->{delay}->{action}};
    }
}

###############################################################################
# Parse parameters of 'create delayed work' action.
#
sub processCreateAction {
    my $self = shift;

    my ($time, $crontab, $skip, $isPaused) = $self->parseDelayScheduling();
    if (defined($time) or defined($crontab)) {
        $self->{delay} = {
            action => DELAY_ACTION_CREATE,
            (defined($time) ? (time => $time) : ()),
            (defined($crontab) ? (
                crontab => $crontab,
                ($skip > 0 ? (skip => $skip) : ()),
                ($isPaused ? (pause => $isPaused) : ())
            ) : ())
        };
    }
}

###############################################################################
# Parse parameters of 'update delayed work' action.
#
sub processUpdateAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        $self->{delay} = {
            action => DELAY_ACTION_UPDATE,
            id     => $id,
        };
    }
}

###############################################################################
# Parse parameters of 'schedule delayed work' action.
#
sub processScheduleAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        my ($time, $crontab, $skip, $isPaused) = $self->parseDelayScheduling();
        if (defined($time) or defined($crontab)) {
            $self->{delay} = {
                action => DELAY_ACTION_SCHEDULE,
                id     => $id,
                (defined($time) ? (time => $time) : ()),
                (defined($crontab) ? (
                    crontab => $crontab,
                    skip    => $skip,
                    pause   => $isPaused
                ) : ())
            };
        }
    }
}

###############################################################################
# Parse parameters of 'skip delayed work' action.
#
sub processSkipAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        if (defined(my $skip = $self->parseDelaySkip())) {
            $self->{delay} = {
                action => DELAY_ACTION_SKIP,
                id     => $id,
                skip   => $skip
            };
        }
    }
}

###############################################################################
# Parse parameters of 'pause delayed work' action.
#
sub processPauseAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        $self->{delay} = {
            action => DELAY_ACTION_PAUSE,
            id     => $id,
            pause  => 1
        };
    }
}

###############################################################################
# Parse parameters of 'resume delayed work' action.
#
sub processResumeAction {
    my $self = shift;

    if (defined(my $id = $self->parseDelayId())) {
        $self->{delay} = {
            action => DELAY_ACTION_RESUME,
            id     => $id,
            pause  => 0
        };
    }
}

###############################################################################
# Parse parameters of 'delete delayed work' action.
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
# Parse parameters of 'get delayed works' action.
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
# Generate delayed work summary if needed to.
#
sub generateSummary {
    my $self = shift;

    if (exists(DELAY_ACTIONS_WITH_SUMMARY()->{$self->{delay}->{action}})) {
        my $escapeRe = qr/[\s\'\"]/;
        my $escapeSub = sub {
            my $arg = shift;
            $arg =~ s/\'/\\\'/g;
            return '\'' . $arg . '\'';
        };

        my @args;
        for (@{$self->{args}}) {
            my $arg = $_;

            my ($name, $value) = ($arg =~ /^([^=]+)(?:\=(.+))?$/);
            unless (defined($value)) {
                if ($arg =~ $escapeRe) {
                    $arg = $escapeSub->($arg);
                }
            } elsif ($name =~ $escapeRe) {
                $arg = $escapeSub->($name . '=' . $value);
            } elsif ($value =~ $escapeRe) {
                $arg = $name . '=' . $escapeSub->($value);
            }

            push @args, $arg;
        }

        $self->{delay}->{summary} = join(' ', @args);
    }
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
# Check if current argument is delay time or crontab specification string and return them.
# If none of the conditions are met, error is reported.
#
# Returns:
#     integer time in unix timestamp format or undef.
#     crontab specification string or undef.
#     skip count or undef.
#     isPaused 0/1 flag or undef.
#
sub parseDelayScheduling {
    my $self = shift;

    my ($time, $crontab, $skip, $isPaused);
    $time = $self->parseDelayTime();
    unless (defined($time)) {
        $crontab = $self->parseDelayCrontab();
    }

    unless (defined($time) or defined($crontab)) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => '@delay',
            text  => 'wrong delay time or crontab specification'
        };
        return +(undef, undef, undef, undef);
    }

    if (defined($crontab)) {
        ($skip, $isPaused) = (0, 0);

        if (scalar(@{$self->{args}}) > 0 and $self->{args}->[0] eq '@skip') {
            shift(@{$self->{args}});
            unless (defined($skip = $self->parseDelaySkip())) {
                return +(undef, undef, undef, undef);
            }
        }

        if (scalar(@{$self->{args}}) > 0 and $self->{args}->[0] eq '@paused') {
            shift(@{$self->{args}});
            $isPaused = 1;
        }
    }

    return +($time, $crontab, $skip, $isPaused);
}

###############################################################################
# Check if current argument is delay time and return it.
#
# Returns:
#     integer time in unix timestamp format or undef in case argument is not delay time.
#
sub parseDelayTime {
    my $self = shift;

    my $dateTime = parseDateTime($self->{args}->[0]);
    unless (defined($dateTime)) {
        return undef;
    }

    shift(@{$self->{args}});
    return $dateTime->{unixTime};
}

###############################################################################
# Check if current argument is crontab specification string and return it.
#
# Returns:
#     crontab specification string or undef in case argument is not crontab specification.
#
sub parseDelayCrontab {
    my $self = shift;

    my $crontab = $self->{args}->[0];
    unless ($self->parent->checkCrontab($crontab)) {
        return undef;
    }

    shift(@{$self->{args}});
    return $crontab;
}

###############################################################################
# Check if current argument is id of delayed work and return it. Otherwise error is reported.
#
# Returns:
#     integer id of delayed work or undef in case of error.
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

###############################################################################
# Check if current argument is integer skip count and return it. Otherwise error is reported.
#
# Returns:
#     integer skip count of delayed work or undef in case of error.
#
sub parseDelaySkip {
    my $self = shift;

    my $skip = shift(@{$self->{args}});
    unless (defined($skip) and $skip =~ /^\d+$/o) {
        push @{$self->{errors}}, {
            type  => 'error',
            field => '@delay',
            text  => 'wrong delay skip count'
        };
        return undef;
    }

    return $skip;
}

1;
