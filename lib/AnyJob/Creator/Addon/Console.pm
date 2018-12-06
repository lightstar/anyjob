package AnyJob::Creator::Addon::Console;

###############################################################################
# Addon that creates jobs using command-line of console application.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  06.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Delay;
use AnyJob::Constants::Events qw(EVENT_GET_DELAYED_WORKS);
use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Creator::Addon::Base';

###############################################################################
# Construct new AnyJob::Creator::Addon::Console object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
# Returns:
#     AnyJob::Creator:Addon::Console object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'console';
    my $self = $class->SUPER::new(%args);
    return $self;
}

###############################################################################
# Do some action using command-line arguments.
# Either job or jobset is created, or some action with delayed work is performed.
# Internally AnyJob::Creator::Parser is used, so see there for details of parsing args.
#
# Arguments:
#     args - array of strings with command-line arguments.
# Returns:
#     reply string with error or success message.
#
sub run {
    my $self = shift;
    my $args = shift;

    my ($delay, $job, $errors);
    ($delay, $job, undef, $errors) = $self->parent->parse($args);
    unless (defined($delay) or defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    $errors = [ grep {$_->{type} eq 'error'} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    unless (defined($delay)) {
        return $self->createJob($job);
    } elsif (exists(DELAY_JOB_ACTIONS()->{$delay->{action}})) {
        return $self->delayJob($delay, $job);
    } elsif ($delay->{action} eq DELAY_ACTION_DELETE) {
        return $self->deleteDelayedWork($delay);
    } elsif ($delay->{action} eq DELAY_ACTION_GET) {
        return $self->getDelayedWorks($delay);
    }
}

###############################################################################
# Create job using data parsed from command-line arguments.
#
# Arguments:
#     job - hash with job data generated by AnyJob::Creator::Parser module.
# Returns:
#     reply string with error or success message.
#
sub createJob {
    my $self = shift;
    my $job = shift;

    $self->debug('Create job using console creator: ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ], { author => 'console' });
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        return 'Error: ' . $error;
    }

    return 'Job created';
}

###############################################################################
# Delay job using data parsed from command-line arguments.
#
# Arguments:
#     delay - hash with delay data generated by AnyJob::Creator::Parser module.
#     job   - hash with job data generated by AnyJob::Creator::Parser module.
# Returns:
#     reply string with error or success message.
#
sub delayJob {
    my $self = shift;
    my $delay = shift;
    my $job = shift;

    $self->debug('Delay job using console creator: ' . encode_json($job) .
        ', delay data: ' . encode_json($delay));

    my $error = $self->parent->delayJobs($delay, [ $job ], { author => 'console' });
    if (defined($error)) {
        $self->debug('Delaying failed: ' . $error);
        return 'Error: ' . $error;
    }

    return 'Job delayed';
}

###############################################################################
# Delete delayed work using data parsed from command-line arguments.
#
# Arguments:
#     delay - hash with delay data generated by AnyJob::Creator::Parser module.
# Returns:
#     reply string with error or success message.
#
sub deleteDelayedWork {
    my $self = shift;
    my $delay = shift;

    $self->debug('Delete delayed work using console creator: ' . encode_json($delay));

    $self->parent->deleteDelayedWork($delay->{id});

    return 'Delayed work removed';
}

###############################################################################
# Retrieve delayed works using data parsed from command-line arguments.
#
# Arguments:
#     delay - hash with delay data generated by AnyJob::Creator::Parser module.
# Returns:
#     reply string with error or result message.
#
sub getDelayedWorks {
    my $self = shift;
    my $delay = shift;

    $self->debug('Get delayed works using console creator: ' . encode_json($delay));

    $self->parent->getDelayedWorks('console', undef, $delay->{id});

    my $response;
    (undef, $response) = $self->parent->redis->blpop('anyjob:observerq:private:console', DELAY_GET_TIMEOUT);
    unless (defined($response)) {
        return 'Error: timeout reached';
    }

    my $event;
    eval {
        $event = decode_json($response);
    };
    if ($@) {
        return 'Error: response is not valid json: ' . $response;
    }

    if ($event->{event} ne EVENT_GET_DELAYED_WORKS) {
        return 'Error: response event does not have valid type: ' . $response;
    }

    if (scalar(@{$event->{works}} == 0)) {
        return 'No delayed works';
    }

    my @workLines;
    foreach my $work (@{$event->{works}}) {
        my $line = $work->{id} . '. ' . $work->{name} . ' (' . formatDateTime($work->{time}) . ')' .
            ' - created by \'' . $work->{props}->{author} . '\' at ' . formatDateTime($work->{props}->{time});
        push @workLines, $line
    }

    return join("\n", @workLines);
}

1;
