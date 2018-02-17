package AnyJob::Creator::App::Slack;

###############################################################################
# Dancer2 web application for creating and observing jobs via slack (https://slack.com/).
#
# Author:       LightStar
# Created:      23.11.2017
# Last update:  16.02.2018
#

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;

###############################################################################
# Dancer2 application settings.
#
set serializer => 'JSON';
set charset => 'UTF-8';

###############################################################################
# Handle request from interactive components.
# (https://api.slack.com/dialogs and https://api.slack.com/docs/message-buttons).
# Only dialog submission supported right now.
# It is expected that 'callback_id' parameter will contain slack builder name before colon.
#
post '/' => sub {
        my $params = body_parameters;

        my $payload;
        eval {
            $payload = decode_json($params->get('payload'));
        };
        if ($@ or ref($payload) ne 'HASH') {
            status 400;
            send_as html => 'Error: wrong payload';
        }

        my $slack = creator->addon('slack');
        unless ($slack->checkToken($payload->{token})) {
            status 401;
            send_as html => 'Error: wrong token';
        }

        unless (defined($payload->{callback_id})) {
            status 400;
            send_as html => 'Error: no callback_id';
        }

        my $user = defined($payload->{user}) ? $payload->{user}->{id} : undef;
        unless ($slack->isUserAllowed($user)) {
            status 401;
            send_as html => 'Error: access denied';
        }

        my ($name) = split(/:/, $payload->{callback_id});
        my $builder = $slack->getBuilder($name);
        unless (defined($builder)) {
            status 400;
            send_as html => 'Error: unknown builder';
        }

        if ($payload->{type} eq 'dialog_submission') {
            my $response = $builder->dialogSubmission($payload);
            if (defined($response)) {
                if (ref($response) eq '') {
                    status 400;
                    send_as html => $response;
                } else {
                    return $response;
                }
            }
        } else {
            status 400;
            send_as html => 'Error: unsupported payload type';
        }

        send_as html => '';
    };

###############################################################################
# Handle request from slash command execution (https://api.slack.com/slash-commands).
#
post '/cmd' => sub {
        my $params = body_parameters;
        my $slack = creator->addon('slack');

        unless ($slack->checkToken($params->get('token'))) {
            status 401;
            send_as html => 'Error: wrong token';
        }

        my $userId = $params->get('user_id');
        unless ($slack->isUserAllowed($userId)) {
            return {
                text => 'Error: access denied'
            };
        }

        my $builder = $slack->getBuilderByCommand(substr($params->get('command'), 1));
        unless (defined($builder)) {
            status 400;
            send_as html => 'Error: unknown command';
        }

        my $text = $params->get('text');
        if ($text eq 'help') {
            return $builder->commandHelp();
        }

        my $response = $builder->command($text, $userId, $params->get('response_url'), $params->get('trigger_id'),
            $params->get('user_name'));
        if (defined($response)) {
            return ref($response) eq '' ? { text => $response } : $response;
        }

        send_as html => '';
    };

###############################################################################
# Initialize creator component before any request.
#
creator;

1;
