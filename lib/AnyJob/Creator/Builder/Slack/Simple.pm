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
    my $responseUrl = shift;

    my ($job, $extra, $errors) = $self->parent->parseJobLine($text);
    unless (defined($job)) {
        return {
            text => 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{error} : 'unknown error')
        };
    }

    $self->debug('Create jobs using slack app simple build by user \'' . $user . '\': ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ], 'su' . $user, $responseUrl);
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
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
