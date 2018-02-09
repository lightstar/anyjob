package AnyJob::Creator::Builder::Slack::Simple;

###############################################################################
# Slack builder used to create job using slash command's text.
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  08.02.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Base';

###############################################################################
# Handle slack slash command. Text is parsed by AnyJob::Creator::Parser module so look there for details.
# Job is created only if AnyJob::Creator::Parser returns no errors (warnings are permitted).
#
# Arguments:
#     text        - string command text.
#     user        - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
# Returns:
#     string result to show user.
#
sub command {
    my $self = shift;
    my $text = shift;
    my $user = shift;
    my $responseUrl = shift;
    my $triggerId = shift;

    my ($job, $errors);
    ($job, undef, $errors) = $self->parent->parseJob($text);
    unless (defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    unless ($self->parentAddon->checkJobAccess($user, $job)) {
        return 'Error: access denied';
    }

    $errors = [ grep {$_->{type} eq 'error'} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    $self->debug('Create jobs using slack app simple build by user \'' . $user . '\': ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ], {
            observer     => 'slack',
            response_url => $responseUrl
        });
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        return 'Error: ' . $error;
    }

    return 'Job created';
}


###############################################################################
# Dialog submission is not supported in this builder.
#
# Arguments:
#     payload - hash data with dialog submission.
# Returns:
#     hash data with response payload, string result to show user or undef.
#
sub dialogSubmission {
    my $self = shift;
    my $payload = shift;

    require Carp;
    Carp::confess('Not supported');
}

1;
