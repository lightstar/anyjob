package AnyJob::Creator::Builder::Slack::Delay::Simple;

###############################################################################
# Slack builder used to delay job or perform some operation with delayed work using slash command's text.
#
# Author:       LightStar
# Created:      06.12.2018
# Last update:  16.01.2019
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_STATUS EVENT_GET_DELAYED_WORKS);
use AnyJob::Constants::Delay;

use base 'AnyJob::Creator::Builder::Slack::Simple';

###############################################################################
# Handle slack slash command. Text is parsed by AnyJob::Creator::Parser module so look there for details.
# Job is delayed (or operation with delayed work is processed) only if AnyJob::Creator::Parser returns no errors
# (warnings are permitted).
#
# Arguments:
#     text        - string command text.
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
# Returns:
#     string result to show user or undef.
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

    unless ($self->parentAddon->checkDelayAccess($userId, $delay)) {
        return 'Error: access denied';
    }

    if (defined($job)) {
        unless ($self->parentAddon->checkJobAccess($userId, $job) and
            $self->parentAddon->checkJobDelayAccess($userId, $delay, $job)
        ) {
            return 'Error: access denied';
        }
    }

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    if ($delay->{action} eq DELAY_ACTION_UPDATE or $delay->{action} eq DELAY_ACTION_DELETE) {
        $self->startDelayedWorkAction($delay, $job, $userId, $responseUrl, $triggerId, $userName);
        return undef;
    } elsif ($delay->{action} eq DELAY_ACTION_CREATE) {
        return $self->delayJob($delay, $job, $userId, $responseUrl, $userName);
    } elsif ($delay->{action} eq DELAY_ACTION_GET) {
        return $self->getDelayedWorks($delay, $userId, $responseUrl, $userName);
    }

    return 'Error: unknown error';
}

###############################################################################
# Start multi-step delayed work action ('update' or 'delete').
#
# Arguments:
#     delay       - hash with delay data.
#     job         - hash with job data or undef.
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

    $self->debug('Start delayed work action using slack app simple build by user \'' . $userId .
        '\' (\'' . $userName . '\') with response url \'' . $responseUrl . '\'' .
        (defined($job) ? ', job: ' . encode_json($job) : '') . ' and delay: ' . encode_json($delay));

    $self->SUPER::startDelayedWorkAction($delay, $job, $userId, $responseUrl, $triggerId, $userName);
}

###############################################################################
# Continue update or delete operation.
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

    $self->debug('Continue delayed work action using slack app simple build by user \'' . $build->{userId} .
        '\' (\'' . $build->{userName} . '\') with response url \'' . $build->{responseUrl} . '\'' .
        (defined($build->{job}) ? ', job: ' . encode_json($build->{job}) : '') .
        ', delay: ' . encode_json($build->{delay}) . ' and event: ' . encode_json($event));

    my $response = undef;
    if (scalar(@{$event->{works}}) != 1) {
        $self->debug('Delayed work action failed: delayed work not found');
        $response = 'Error: delayed work not found';
    } else {
        my $action = $build->{delay}->{action};
        my $work = $event->{works}->[0];

        unless ($self->parentAddon->checkDelayedWorkAccess($build->{userId}, $action, $work)) {
            $self->debug('Delayed work action failed: access denied');
            $response = 'Error: access denied';
        } elsif ($action eq DELAY_ACTION_UPDATE) {
            $response = $self->delayJob($build->{delay}, $build->{job}, $build->{responseUrl}, $build->{userName},
                $work->{update});
        } elsif ($action eq DELAY_ACTION_DELETE) {
            $response = $self->deleteDelayedWork($build->{delay}, $build->{responseUrl}, $build->{userName},
                $work->{update});
        }
    }

    $self->cleanBuild($id);

    if (defined($response)) {
        $self->sendResponse({ text => $response }, $build->{responseUrl});
    }
}

###############################################################################
# Delay job using data parsed from input arguments.
#
# Arguments:
#     delay       - hash with delay data generated by AnyJob::Creator::Parser module.
#     job         - hash with job data generated by AnyJob::Creator::Parser module.
#     userId      - string user id.
#     responseUrl - string response url.
#     userName    - string user name.
#     updateCount - update count which must be checked for permanence before updating or undef.
# Returns:
#     reply string with error or success message. Can be undef if result is not yet known. In that case final operation
#     result will be received via status event from delay controller.
#
sub delayJob {
    my $self = shift;
    my $delay = shift;
    my $job = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $userName = shift;
    my $updateCount = shift;

    $self->debug('Delay job using slack app simple build by user \'' . $userId . '\' (\'' .
        $userName . '\') with response url \'' . $responseUrl . '\'' .
        (defined($updateCount) ? ', update count: ' . $updateCount : '') .
        ', job: ' . encode_json($job) . ' and delay: ' . encode_json($delay));

    my $opts = undef;
    if (exists($delay->{id}) and defined($updateCount)) {
        $opts = {
            check_update   => $updateCount,
            status_service => $self->name
        };
    }

    my $error = $self->parent->delayJobs($delay, [ $job ], {
        creator      => 'slack',
        author       => $userName,
        observer     => 'slack',
        response_url => $responseUrl
    }, $opts);

    if (defined($error)) {
        $self->debug('Delaying failed: ' . $error);
        return 'Error: ' . $error;
    }

    if (exists($delay->{id}) and defined($updateCount)) {
        return undef;
    }

    return exists($delay->{id}) ? 'Delayed work updated' : 'Job delayed';
}

###############################################################################
# Delete delayed work using data parsed from input arguments.
#
# Arguments:
#     delay       - hash with delay data generated by AnyJob::Creator::Parser module.
#     responseUrl - string response url.
#     userName    - string user name.
#     updateCount - update count which must be checked for permanence before deleting or undef.
# Returns:
#     reply string with error or success message. Can be undef if result is not yet known. In that case final operation
#     result will be received via status event from delay controller.
#
sub deleteDelayedWork {
    my $self = shift;
    my $delay = shift;
    my $responseUrl = shift;
    my $userName = shift;
    my $updateCount = shift;

    $self->debug('Delete delayed work using slack app simple build by user \'' . $userId .
        '\' (\'' . $userName . '\') with response url \'' . $responseUrl . '\'' .
        (defined($updateCount) ? ', update count: ' . $updateCount : '') .
        ' and delay: ' . encode_json($delay));

    my $opts = undef;
    if (defined($updateCount)) {
        $opts = {
            check_update   => $updateCount,
            status_service => $self->name
        };
    }

    $self->parent->deleteDelayedWork($delay->{id}, {
        creator      => 'slack',
        author       => $userName,
        observer     => 'slack',
        response_url => $responseUrl
    }, $opts);

    if (defined($updateCount)) {
        return undef;
    }

    return 'Delayed work removed';
}

###############################################################################
# Retrieve delayed works using data parsed from input arguments.
#
# Arguments:
#     delay       - hash with delay data generated by AnyJob::Creator::Parser module.
#     userId      - string user id.
#     responseUrl - string response url.
#     userName    - string user name.
# Returns:
#     reply string with error or result message.
#
sub getDelayedWorks {
    my $self = shift;
    my $delay = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $userName = shift;

    $self->debug('Get delayed works using slack app simple build by user \'' . $userId . '\' (\'' .
        $userName . '\') with response url \'' . $responseUrl . '\' and delay: ' . encode_json($delay));

    $self->parent->getDelayedWorks('slack', $delay->{id}, {
        creator      => 'slack',
        author       => $userName,
        response_url => $responseUrl,
        user         => $userId
    });

    return undef;
}

1;
