package AnyJob::Creator::Builder::Slack::Delay::Dialog;

###############################################################################
# Slack builder used to delay job using dialog shown on slash command.
# See https://api.slack.com/dialogs for details.
#
# Author:       LightStar
# Created:      09.12.2018
# Last update:  16.01.2019
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
        $self->parentAddon->checkDelayAccess($userId, $delay) and
        $self->parentAddon->checkJobDelayAccess($userId, $delay, $job)
    ) {
        return 'Error: access denied';
    }

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    if ($delay->{action} eq DELAY_ACTION_UPDATE) {
        $self->startDelayedWorkAction($delay, $job, $userId, $responseUrl, $triggerId, $userName);
        return undef;
    }

    my $error = $self->createAndShowDialog($delay, $job, $userId, $responseUrl, $triggerId, $userName);
    if (defined($error)) {
        return $error;
    }

    return undef;
}

###############################################################################
# Start multi-step delayed work update action.
#
# Arguments:
#     delay       - hash with delay data.
#     job         - hash with job data.
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
#
sub startDelayedWorkAction {
    my $self = shift;
    my $delay = shift;
    my $job = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;

    $self->debug('Start delayed work action using slack app dialog build by user \'' . $userId . '\' (\'' . $userName .
        '\') with response url \'' . $responseUrl . '\', trigger \'' . $triggerId . '\', job: ' . encode_json($job) .
        ' and delay: ' . encode_json($delay));

    $self->SUPER::startDelayedWorkAction($delay, $job, $userId, $responseUrl, $triggerId, $userName);
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

    $self->debug('Continue delayed work action using slack app dialog build by user \'' . $build->{userId} .
        '\' (\'' . $build->{userName} . '\') with response url \'' . $build->{responseUrl} . '\', trigger \'' .
        $build->{triggerId} . '\', job: ' . encode_json($build->{job}) . ', delay: ' . encode_json($build->{delay}) .
        ' and event: ' . encode_json($event));

    my $error = undef;
    if (scalar(@{$event->{works}}) != 1) {
        $error = 'delayed work not found';
    } else {
        my $action = $build->{delay}->{action};
        my $work = $event->{works}->[0];

        unless ($self->parentAddon->checkDelayedWorkAccess($build->{userId}, $action, $work)) {
            $error = 'access denied';
        } elsif ($action eq DELAY_ACTION_UPDATE) {
            $error = $self->createAndShowDialog($build->{delay}, $build->{job}, $build->{userId},
                $build->{responseUrl}, $build->{trigger}, $build->{userName}, $work->{update});
        }
    }

    $self->cleanBuild($id);

    if (defined($error)) {
        $self->debug('Delayed work action failed: ' . $error);
        $self->sendResponse({ text => 'Error: ' . $error }, $build->{responseUrl});
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
#     updateCount - update count which must be checked for permanence before updating or undef.
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

    $self->debug('Create slack app dialog build \'' . $id . '\' by user \'' . $userId . '\' (\'' .
        $userName . '\') with response url \'' . $responseUrl . '\', trigger \'' . $triggerId . '\'' .
        (defined($updateCount) ? ', update count: ' . $updateCount : '') .
        ', job: ' . encode_json($job) . ' and delay: ' . encode_json($delay));

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

    my $opts = undef;
    if (exists($build->{delay}->{id}) and defined($build->{updateCount})) {
        $opts = {
            check_update   => $build->{updateCount},
            status_service => $self->name
        };
    }

    my $error = $self->parent->delayJobs($build->{delay}, [ $build->{job} ], {
        creator      => 'slack',
        author       => $build->{userName},
        observer     => 'slack',
        response_url => $build->{responseUrl}
    }, $opts);

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
