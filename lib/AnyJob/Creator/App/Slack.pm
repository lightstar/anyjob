package AnyJob::Creator::App::Slack;

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;

set serializer => 'JSON';
set charset => 'UTF-8';

post '/' => sub {
        debug(request->body);
        send_as html => 'OK';
    };

post '/cmd' => sub {
        my $params = body_parameters;
        my $slack = creator->addon('slack');

        unless ($slack->checkToken($params->get('token'))) {
            return {
                text => 'Error: wrong token'
            };
        }

        my $builder = $slack->getBuilder(substr($params->get('command'), 1));
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
