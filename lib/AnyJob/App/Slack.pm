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
        my $slack = creator->addon('slack');

        unless ($slack->checkToken($params->get('token'))) {
            send_as html => 'Error: wrong token';
        }

        my $user = $params->get('user_id');
        unless ($slack->isUserAllowed($user)) {
            send_as html => 'Error: user not allowed';
        }

        my ($job, $extra, $error) = creator->parseJobLine($params->get('text'));
        if (defined($error)) {
            send_as html => 'Error: ' . $error;
        }

        if ($extra->{dialog} or defined(creator->createJobs([ $job ], 'su' . $user))) {
            if (defined($slack->sendDialog($slack->getJobDialog($job, $params->get('trigger_id'))))) {
                send_as html => '';
            } else {
                send_as html => 'Error: failed to open dialog';
            }
        } else {
            send_as html => 'Job created';
        }
    };

1;
