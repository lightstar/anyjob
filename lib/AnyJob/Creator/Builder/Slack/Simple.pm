package AnyJob::Creator::Builder::Slack::Simple;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Base';

sub build {
    my $self = shift;
    my $text = shift;
    my $user = shift;

    my ($job, $extra, $errors) = $self->parent->parseJobLine($text);
    $self->debug('Simple build, text: ' . $text . ', job: ' . (defined($job) ? encode_json($job) : 'undef') .
        ', errors: ' . encode_json($errors));

    unless (defined($job)) {
        return {
            text => 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{error} : 'unknown error')
        };
    }

    my $error = $self->parent->createJobs([ $job ], 'su' . $user);
    if (defined($error)) {
        return {
            text => 'Error: ' . $error
        }
    } else {
        return {
            text => 'Job created'
        }
    }
}

1;
