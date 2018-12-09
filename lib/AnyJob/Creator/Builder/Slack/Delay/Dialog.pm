package AnyJob::Creator::Builder::Slack::Delay::Dialog;

###############################################################################
# Slack builder used to delay job using dialog shown on slash command.
# See https://api.slack.com/dialogs for details.
#
# Author:       LightStar
# Created:      09.12.2018
# Last update:  09.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Dialog';

###############################################################################
# Handle slack slash command to delay job. Text is parsed by AnyJob::Creator::Parser module so look there for details.
# If parsing returns no unrecoverable errors, result is saved in build object and dialog is shown
# so user can clarify job parameters.
#
# Arguments:
#     text        - string command text.
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
# Returns:
#     string result to show to user or undef.
#
sub command {
    my $self = shift;
    my $text = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;

    my ($delay, $job, $errors);
    ($delay, $job, undef, $errors) = $self->parent->parse($text, undef, { delay => 1 });

    unless (defined($delay)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    unless (defined($job)) {
        return 'Error: dialog can only be used with job';
    }

    unless ($self->parentAddon->checkJobAccess($userId, $job) and
        $self->parentAddon->checkDelayAccess($userId, $delay)
    ) {
        return 'Error: access denied';
    }

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    my ($dialog, $id, $error) = $self->createDialogAndBuild($userId, $responseUrl, $triggerId, $userName,
        $job, { delay => $delay });
    if (defined($error)) {
        return $error;
    }

    $self->debug('Create slack app dialog build \'' . $id . '\' by user \'' . $userId . '\' (\'' . $userName .
        '\') with response url \'' . $responseUrl . '\', trigger \'' . $triggerId . '\', job: ' . encode_json($job) .
        ' and delay: ' . encode_json($delay));

    $self->showDialog($triggerId, $dialog);

    return undef;
}

###############################################################################
# Action name to show in dialog.
#
# Returns:
#     string action name.
#
sub action {
    my $self = shift;
    return 'Delay';
}

###############################################################################
# Handle dialog submission. Finish build and delay job here if there are no errors.
#
# Arguments:
#     payload - hash data with dialog submission.
# Returns:
#     hash data with response payload, string result to show to user or undef.
#
sub dialogSubmission {
    my $self = shift;
    my $payload = shift;

    my ($build, $error) = $self->finishBuild($payload);
    if (defined($error)) {
        return $error;
    }

    $self->debug('Delay jobs using slack app dialog build: ' . encode_json($build));

    my $error = $self->parent->delayJobs($build->{delay}, [ $build->{job} ], {
        creator      => 'slack',
        author       => $build->{userName},
        observer     => 'slack',
        response_url => $build->{responseUrl}
    });
    if (defined($error)) {
        $self->debug('Delaying failed: ' . $error);
        $self->sendResponse({ text => 'Error: ' . $error }, $build->{responseUrl});
    } else {
        $self->sendResponse({ text => 'Job delayed' }, $build->{responseUrl});
    }

    return undef;
}

1;