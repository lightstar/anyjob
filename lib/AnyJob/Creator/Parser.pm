package AnyJob::Creator::Parser;

###############################################################################
# Class used to parse text command-line into hashes with job and delay data which can be fed to different creator's
# methods like 'createJobs' and 'delayJobs'. If there are any errors or warnings in arguments, they are returned
# in very detailed form. Additionally command-line can contain some pre-defined extra arguments which are also returned
# as separate hash.
#
# Internally two parser classes are used - AnyJob::Creator::Parser::Delay and AnyJob::Creator::Parser::Job.
# So for specific details about command-line syntax look there.
# At first if command-line begins with parameter '@delay' (which by itself is skipped) it is parsed by
# AnyJob::Creator::Parser::Delay class. After that if there is no errors and delay data contains job-related action
# (i.e. 'create' or 'update'), AnyJob::Creator::Parser::Job class is used on remained parameters.
# If command-line doesn't begins with '@delay', then AnyJob::Creator::Parser::Job is used to parse entire command line.
#
# Author:       LightStar
# Created:      23.11.2017
# Last update:  08.12.2018
#

use strict;
use warnings;
use utf8;

use Text::ParseWords qw(parse_line);

use AnyJob::Constants::Delay;
use AnyJob::Creator::Parser::Job;
use AnyJob::Creator::Parser::Delay;

###############################################################################
# Construct new AnyJob::Creator::Parser object.
#
# Arguments:
#     parent       - parent component which is usually AnyJob::Creator object.
#     input        - input command-line as raw string text.
#     args         - already parsed array of string arguments (alternative to 'input').
#     allowedExtra - array of strings with allowed additional params in command-line which will be returned in
#                    separate hash after parsing.
#     options      - optional hash with extra options. Supported ones are:
#                      - no_delay - skip parsing special '@delay' argument in front of input.
#                      - delay    - consider delay data in input (as with '@delay' argument in front).
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

    unless (defined($self->{args})) {
        unless (defined($self->{input})) {
            require Carp;
            Carp::confess('No args or input provided');
        }
        $self->{args} = [ parse_line('\s+', 0, $self->{input}) ];
    }

    $self->{allowedExtra} ||= {};
    $self->{options} ||= {};
    $self->{errors} = [];

    $self->{jobParser} = undef;
    $self->{delayParser} = undef;

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
#     hash with parsed job data as described in creator's 'createJobs' method or undef.
#
sub job {
    my $self = shift;
    return defined($self->{jobParser}) ? $self->{jobParser}->job : undef;
}

###############################################################################
# Returns:
#     hash with additional parameters parsed by AnyJob::Creator::Parser::Job class or undef. Look there for details.
#
sub extra {
    my $self = shift;
    return defined($self->{jobParser}) ? $self->{jobParser}->extra : undef;
}

###############################################################################
# Returns:
#     hash with parsed delay data parsed by AnyJob::Creator::Parser::Delay class or undef. Look there for details.
#
sub delay {
    my $self = shift;
    return defined($self->{delayParser}) ? $self->{delayParser}->delay : undef;
}

###############################################################################
# Returns:
#     array of hashes with errors returned by inner parser classes. Look there for details.
#
sub errors {
    my $self = shift;
    return $self->{errors};
}

###############################################################################
# Parse command-line.
# After this method is finished, you may call 'delay', 'job', 'extra' and 'errors' methods to fetch results.
#
sub parse {
    my $self = shift;

    my $isDelay = $self->{options}->{delay} ? 1 : 0;
    if (not $self->{options}->{no_delay} and scalar(@{$self->{args}}) > 0 and $self->{args}->[0] eq '@delay') {
        shift(@{$self->{args}});
        $isDelay = 1;
    }

    my $delayAction = undef;
    if ($isDelay) {
        $self->{delayParser} = AnyJob::Creator::Parser::Delay->new(
            parent => $self->{parent},
            args   => $self->{args}
        );
        $self->{delayParser}->parse();

        push @{$self->{errors}}, @{$self->{delayParser}->errors()};
        if (grep {$_->{type} eq 'error'} @{$self->{errors}}) {
            return;
        }

        $delayAction = $self->{delayParser}->delay->{action};
        $self->{args} = $self->{delayParser}->args;
    }

    if (not defined($delayAction) or exists(DELAY_JOB_ACTIONS()->{$delayAction})) {
        $self->{jobParser} = AnyJob::Creator::Parser::Job->new(
            parent       => $self->{parent},
            args         => $self->{args},
            allowedExtra => $self->{allowedExtra}
        );

        unless (defined($self->{jobParser}->prepare())) {
            push @{$self->{errors}}, @{$self->{jobParser}->{errors}};
            return;
        }

        $self->{jobParser}->parse();

        push @{$self->{errors}}, @{$self->{jobParser}->errors()};
    }
}

1;
