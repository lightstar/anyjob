package AnyJob::Creator::Builder::Slack::Simple;

###############################################################################
# Slack builder used to create job using slash command's text.
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  13.12.2018
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
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
# Returns:
#     string result to show user.
#
sub command {
    my $self = shift;
    my $text = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;

    my ($delay, $job, $errors);
    ($delay, $job, undef, $errors) = $self->parent->parse($text, undef, { no_delay => 1 });
    unless (defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    unless ($self->parentAddon->checkJobAccess($userId, $job)) {
        return 'Error: access denied';
    }

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    $self->debug('Create jobs using slack app simple build by user \'' . $userId . '\' (\'' . $userName .
        '\'): ' . encode_json($job));

    my $error = $self->parent->createJobs([ $job ], {
        creator      => 'slack',
        author       => $userName,
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
# Check errors returned by AnyJob::Creator::Parser module and return error string if they are unrecoverable.
#
# Arguments:
#     errors - array with parse errors.
# Returns:
#     string error to show to user or undef.
#
sub checkParseErrors {
    my $self = shift;
    my $errors = shift;

    $errors = [ grep {$_->{type} eq 'error'} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    return undef;
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
