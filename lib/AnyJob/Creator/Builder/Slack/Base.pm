package AnyJob::Creator::Builder::Slack::Base;

###############################################################################
# Base abstract class for all builders used to create jobs by slack application (http://slack.com/).
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  14.02.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

use AnyJob::Constants::Defaults qw(DEFAULT_SLACK_API);

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

    $self->{ua} = LWP::UserAgent->new();
    $self->{ua}->timeout(15);

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
# Returns:
#     1/undef on success/error accordingly.
#
sub sendResponse {
    my $self = shift;
    my $response = shift;
    my $url = shift;

    my $request = POST($url,
        Content_Type => 'application/json; charset=utf-8',
        Content      => encode_json($response)
    );

    my $result = $self->{ua}->request($request);
    unless ($result->is_success) {
        $self->error('Slack request failed, url: ' . $url . ', response: ' . $result->content);
        return undef;
    }

    return 1;
}

###############################################################################
# Call slack Web API method. See https://api.slack.com/web for details.
#
# Arguments:
#     method - string method name.
#     data   - hash with body data.
# Returns:
#     hash with response data or undef on error.
#
sub callApiMethod {
    my $self = shift;
    my $method = shift;
    my $data = shift;

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
    my $request = POST($url,
        Content_Type  => 'application/json; charset=utf-8',
        Authorization => 'Bearer ' . $config->{api_token},
        Content       => encode_json($data)
    );

    my $result = $self->{ua}->request($request);
    my $response;
    unless ($result->is_success) {
        $self->error('Slack method failed, url: ' . $url . ', response: ' . $result->content);
        return undef;
    } else {
        eval {
            $response = decode_json($result->content);
        };
        if ($@ or not $response->{ok}) {
            $self->error('Slack method failed, url: ' . $url . ', response: ' . $result->content);
            return undef;
        }
    }

    return $response;
}

###############################################################################
# Call Web API method to show dialog. See https://api.slack.com/dialogs for details.
#
# Arguments:
#     triggerId - string trigger id.
#     dialog    - hash with dialog data.
# Returns:
#     1/undef on success/error accordingly.
#
sub showDialog {
    my $self = shift;
    my $triggerId = shift;
    my $dialog = shift;

    unless (defined($self->callApiMethod('dialog.open', {
            trigger_id => $triggerId,
            dialog     => $dialog
        })
    )) {
        return undef;
    }

    return 1;
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
