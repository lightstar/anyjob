package AnyJob::App::Slack;

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

        unless (creator->addon('slack')->checkToken($params->get('token'))) {
            send_as html => 'Error: wrong token';
        }

        my $user = $params->get('user_id');
        unless (creator->addon('slack')->isUserAllowed($user)) {
            send_as html => 'Error: user not allowed';
        }

        my ($job, $extra, $error) = creator->parseJobLine($params->get('text'));
        if (defined($error)) {
            send_as html => 'Error: ' . $error;
        }

        if (defined($error = creator->createJobs([ $job ], 'su' . $user))) {
            send_as html => 'Error: ' . $error;
        }

        send_as html => 'Job created';
    };

1;
