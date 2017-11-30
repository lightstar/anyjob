package AnyJob::Creator::Addon::Console;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Addon::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'console';
    my $self = $class->SUPER::new(%args);
    return $self;
}

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
