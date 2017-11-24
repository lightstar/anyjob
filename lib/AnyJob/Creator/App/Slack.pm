package AnyJob::Creator::App::Slack;

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;

set serializer => 'JSON';
set charset => 'UTF-8';

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

        my ($name) = split(/:/, $payload->{callback_id});
        my $builder = $slack->getBuilder($name);
        unless (defined($builder)) {
            status 400;
            send_as html => 'Error: unknown builder';
        }

        my $response = $builder->update($payload);
        if (defined($response)) {
            if (ref($response) eq '') {
                status 400;
                send_as html => $response;
            } else {
                return $response;
            }
        }

        send_as html => '';
    };

post '/cmd' => sub {
        my $params = body_parameters;
        my $slack = creator->addon('slack');

        unless ($slack->checkToken($params->get('token'))) {
            status 401;
            send_as html => 'Error: wrong token';
        }

        my $builder = $slack->getBuilderByCommand(substr($params->get('command'), 1));
        unless (defined($builder)) {
            return {
                text => 'Error: unknown command'
            };
        }

        my $user = $params->get('user_id');
        unless ($builder->isUserAllowed($user)) {
            return {
                text => 'Error: access denied'
            };
        }

        my $response = $builder->build($params->get('text'), $user, $params->get('response_url'),
            $params->get('trigger_id'));
        if (defined($response)) {
            return $response;
        }

        send_as html => '';
    };

1;
