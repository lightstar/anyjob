package AnyJob::Creator::Builder::Slack::Simple;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Base';

sub command {
    my $self = shift;
    my $text = shift;
    my $user = shift;
    my $responseUrl = shift;

    my ($job, $errors);
    ($job, undef, $errors) = $self->parent->parseJobLine($text);
    unless (defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    $errors = [ grep {$_->{type} eq 'error'} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    $self->debug('Create jobs using slack app simple build by user \'' . $user . '\': ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ], {
            observer     => 'su' . $user,
            response_url => $responseUrl
        });
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        return 'Error: ' . $error;
    }

    return 'Job created';
}

1;
