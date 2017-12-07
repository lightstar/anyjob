package AnyJob::Creator::Addon::Console;

###############################################################################
# Addon that creates jobs using command-line of console application.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  07.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

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
# Create job using command-line arguments.
# Internally AnyJob::Creator::Parser is used, so see there for details of parsing args.
#
# Arguments:
#     args - array of strings with command-line arguments.
# Returns:
#     reply string with error or success message.
#
sub create {
    my $self = shift;
    my $args = shift;

    my ($job, $errors);
    ($job, undef, $errors) = $self->parent->parseJob($args);
    unless (defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    $errors = [ grep {$_->{type} eq 'error'} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    $self->debug('Create job using console creator: ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ]);
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        return 'Error: ' . $error;
    }

    return 'Job created';
}

1;
