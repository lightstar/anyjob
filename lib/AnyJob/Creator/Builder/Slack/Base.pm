package AnyJob::Creator::Builder::Slack::Base;

###############################################################################
# Base abstract class for all builders used to create jobs by slack application (http://slack.com/).
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  15.01.2019
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use AnyEvent::HTTP;
use Scalar::Util qw(weaken);

use AnyJob::Constants::Defaults qw(DEFAULT_SLACK_API);
use AnyJob::Constants::Events qw(EVENT_STATUS EVENT_GET_DELAYED_WORKS);

use base 'AnyJob::Creator::Builder::Base';

###############################################################################
# Construct new AnyJob::Creator::Builder::Slack::Base object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
#     name   - string builder's name used to distinguish builders in configuration and other places.
# Returns:
#     AnyJob::Creator::Builder::Slack::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    return $self;
}

###############################################################################
# Returns:
#     parent component's slack addon object.
#
sub parentAddon {
    my $self = shift;
    return $self->{parent}->addon('slack');
}

###############################################################################
# Get builder configuration or undef.
#
# Returns:
#     hash with builder configuration or undef if there are no such builder in config.
#
sub getBuilderConfig {
    my $self = shift;
    return $self->config->getBuilderConfig('slack_' . $self->name);
}

###############################################################################
# Send message payload to provided response url.
#
# Arguments:
#     response - hash with message payload. Content can be anything supported by slack.
#                See https://api.slack.com/docs/messages for details.
#     url      - string response url.
#
sub sendResponse {
    my $self = shift;
    my $response = shift;
    my $url = shift;

    weaken($self);
    http_post($url, encode_json($response), headers => {
        'Content-Type' => 'application/json; charset=utf-8'
    }, sub {
        my ($body, $headers) = @_;
        if (defined($self) and $headers->{Status} !~ /^2/) {
            $self->parent->setBusy(1);
            $self->error('Slack request failed, url: ' . $url . ', response: ' . $body);
            $self->parent->setBusy(0);
        }
    });
}

###############################################################################
# Call slack Web API method. See https://api.slack.com/web for details.
#
# Arguments:
#     method   - string method name.
#     data     - hash with body data.
#     callback - optional callback function which will be called when result is ready.
#                It will receive hash with response data as first argument or undef in case of error.
#
sub callApiMethod {
    my $self = shift;
    my $method = shift;
    my $data = shift;
    my $callback = shift;

    unless (defined($method) and defined($data)) {
        require Carp;
        Carp::confess('No slack api method or data');
    }

    my $config = $self->config->getCreatorConfig('slack') || {};
    unless (defined($config->{api_token})) {
        require Carp;
        Carp::confess('No token for slack api calls');
    }

    my $api = $config->{api} || DEFAULT_SLACK_API;
    my $url = $api . $method;

    weaken($self);
    http_post($url, encode_json($data), headers => {
        'Content-Type' => 'application/json; charset=utf-8',
        Authorization  => 'Bearer ' . $config->{api_token}
    }, sub {
        my ($body, $headers) = @_;
        if (defined($self)) {
            my $result;
            $self->parent->setBusy(1);
            if ($headers->{Status} !~ /^2/) {
                $self->error('Slack method failed, url: ' . $url . ', response: ' . $body);
            } else {
                my $response;
                eval {
                    $response = decode_json($body);
                };
                if ($@ or not $response->{ok}) {
                    $self->error('Slack method failed, url: ' . $url . ', response: ' . $body);
                } else {
                    $result = $response;
                }
            }
            if (defined($callback)) {
                $callback->($result);
            }
            $self->parent->setBusy(0);
        }
    });
}

###############################################################################
# Call Web API method to show dialog. See https://api.slack.com/dialogs for details.
#
# Arguments:
#     triggerId - string trigger id.
#     dialog    - hash with dialog data.
#     callback - optional callback function which will be called when result is ready.
#                It will receive hash with response data as first argument or undef in case of error.
#
sub showDialog {
    my $self = shift;
    my $triggerId = shift;
    my $dialog = shift;
    my $callback = shift;

    $self->callApiMethod('dialog.open', {
        trigger_id => $triggerId,
        dialog     => $dialog
    }, $callback);
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
        my $text = $event->{success} ? $event->{message} : 'Error: ' . lcfirst($event->{message});
        $self->sendResponse({ text => $text }, $event->{props}->{response_url});
    } elsif ($event->{event} eq EVENT_GET_DELAYED_WORKS) {
        $self->continueDelayedWorkAction($event);
    }
}

###############################################################################
# Start multi-step delayed work action ('update' or 'delete'). Special build is created here and service command
# 'get delayed works' is initiated to get delayed work user wishes to update or delete.
# Later on builder will receive service event 'get delayed works' and process it to continue operation.
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

    my $params = {
        userId      => $userId,
        userName    => $userName,
        job         => $job,
        delay       => $delay,
        trigger     => $triggerId,
        responseUrl => $responseUrl
    };

    my $id = $self->getNextBuildId();
    $self->redis->zadd('anyjob:builds', time() + $self->getCleanTimeout(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json($params));

    $self->parent->getDelayedWorks('slack', $delay->{id}, {
        service => $self->name . ':' . $id
    });
}

###############################################################################
# Continue multi-step delayed work action.
#
# Arguments:
#     event - hash with event data.
#
sub continueDelayedWorkAction {
    my $self = shift;
    my $event = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

###############################################################################
# Show help for slack command.
#
# Returns:
#     hash data with help message payload.
#
sub commandHelp {
    my $self = shift;

    my $config = $self->getBuilderConfig() || {};
    return {
        text => $config->{help} || 'No help for this command'
    };
}

###############################################################################
# Handle slack slash command. See https://api.slack.com/slash-commands for details.
# This is abstract method, needed to be implemented in descendants.
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

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

###############################################################################
# Handle dialog submission. See https://api.slack.com/dialogs for details.
# This is abstract method, needed to be implemented in descendants.
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
    Carp::confess('Need to be implemented in descendant');
}

1;
