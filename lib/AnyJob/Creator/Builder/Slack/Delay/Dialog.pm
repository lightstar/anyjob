package AnyJob::Creator::Builder::Slack::Delay::Dialog;

###############################################################################
# Slack builder used to delay job using dialog shown on slash command.
# See https://api.slack.com/dialogs for details.
#
# Author:       LightStar
# Created:      09.12.2018
# Last update:  15.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_STATUS EVENT_GET_DELAYED_WORKS);
use AnyJob::Constants::Delay;

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
        $self->parentAddon->checkDelayAccess($userId, $delay, $job)
    ) {
        return 'Error: access denied';
    }

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    if ($delay->{action} eq DELAY_ACTION_UPDATE) {
        $self->createGetDelayedWorkBuild($delay, $job, $userId, $responseUrl, $triggerId, $userName);
        return undef;
    }

    my $error = $self->createAndShowDialog($delay, $job, $userId, $responseUrl, $triggerId, $userName);
    if (defined($error)) {
        return $error;
    }

    return undef;
}

###############################################################################
# Method which will be called when new service event arrives.
#
# Arguments:
#     event - hash with event data.
#
sub receiveServiceEvent {
    my $self = shift;
    my $event = shift;

    if ($event->{event} eq EVENT_STATUS) {
        $self->sendResponse({ text => $event->{message} }, $event->{props}->{response_url});
    } elsif ($event->{event} eq EVENT_GET_DELAYED_WORKS) {
        $self->continueDelayedWorkAction($event);
    }
}

###############################################################################
# Continue update operation.
#
# Arguments:
#     event - hash with event data.
#
sub continueDelayedWorkAction {
    my $self = shift;
    my $event = shift;

    my ($id, $build);
    (undef, $id) = split(/:/, $event->{props}->{service});
    unless (defined($id) and defined($build = $self->getBuild($id))) {
        return;
    }
    my $response = undef;
    if (scalar(@{$event->{works}}) != 1) {
        $response = 'Error: delayed work not found';
    } else {
        my $action = $build->{delay}->{action};
        my $work = $event->{works}->[0];

        unless ($self->parentAddon->checkDelayedWorkAccess($build->{userId}, $action, $work)) {
            $response = 'Error: access denied';
        } elsif ($action eq DELAY_ACTION_UPDATE) {
            $response = $self->createAndShowDialog($build->{delay}, $build->{job}, $build->{userId},
                $build->{responseUrl}, $build->{trigger}, $build->{userName}, $work->{update});
        }
    }

    $self->cleanBuild($id);

    if (defined($response)) {
        $self->sendResponse({ text => $response }, $build->{responseUrl});
    }
}

###############################################################################
# Create dialog and show it.
#
# Arguments:
#     delay       - hash with delay data.
#     job         - hash with job data.
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
#     updateCount - update count which must be checked for permanence before updating.
# Returns:
#     string error to show to user or undef.
#
sub createAndShowDialog {
    my $self = shift;
    my $delay = shift;
    my $job = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;
    my $updateCount = shift;

    my ($dialog, $id, $error) = $self->createDialogAndBuild($userId, $responseUrl, $triggerId, $userName, $job, {
        delay => $delay,
        ((exists($delay->{id}) and defined($updateCount)) ? (checkUpdate => $updateCount) : ())
    });

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

    my $props = {
        creator      => 'slack',
        author       => $build->{userName},
        observer     => 'slack',
        response_url => $build->{responseUrl}
    };

    if (exists($build->{delay}->{id}) and exists($build->{updateCount})) {
        $props->{check_update} = $build->{updateCount};
        $props->{status_service} = $self->name;
    }

    my $error = $self->parent->delayJobs($build->{delay}, [ $build->{job} ], $props);

    if (defined($error)) {
        $self->debug('Delaying failed: ' . $error);
        $self->sendResponse({ text => 'Error: ' . $error }, $build->{responseUrl});
    } elsif (not exists($build->{delay}->{id}) or not exists($build->{updateCount})) {
        my $response = exists($build->{delay}->{id}) ? 'Delayed work updated' : 'Job delayed';
        $self->sendResponse({ text => $response }, $build->{responseUrl});
    }

    return undef;
}

1;
