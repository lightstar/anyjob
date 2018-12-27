package AnyJob::Creator::App::Web;

###############################################################################
# Dancer2 web application for creating and observing jobs via browser.
# Requires client-side files in 'web' directory.
#
# Author:       LightStar
# Created:      23.11.2017
# Last update:  27.12.2018
#

use strict;
use warnings;
use utf8;

use CGI::Deurl::XS qw(parse_query_string);

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;
use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;
use Dancer2::Plugin::WebSocket;

use AnyJob::Constants::Delay;
use AnyJob::DateTime qw(parseDateTime);

###############################################################################
# Dancer2 application settings.
#
set public_dir => path(app->location, 'web');
set static_handler => true;
set serializer => 'JSON';
set charset => 'UTF-8';
set plugins => {
    'Auth::HTTP::Basic::DWIW' => {
        realm => 'AnyJob'
    },
    WebSocket                 => {
        mount_path => '/ws',
        serializer => {
            utf8         => 1,
            allow_nonref => 1
        }
    }
};

###############################################################################
# Basic authorization handler.
#
# Arguments:
#     user - string user name.
#     pass - string password.
# Returns:
#     0/1 flag. If set, access is permitted.
#
http_basic_auth_set_check_handler sub {
    my $user = shift;
    my $pass = shift;
    return creator->addon('web')->checkAuth($user, $pass);
};

###############################################################################
# Handle root path. Index page is sent here.
#
get '/' => http_basic_auth required => sub {
    send_file '/index.html';
};

###############################################################################
# Retrieve hash with config data needed by client-side of web application.
#
get '/config' => http_basic_auth required => sub {
    my ($user, $pass) = http_basic_auth_login;
    my $web = creator->addon('web');
    return {
        jobs            => $web->getUserJobs($user),
        props           => $web->getUserProps($user),
        delayRestricted => $web->getUserDelayRestricted($user),
        observer        => {
            eventTemplate => $web->getEventTemplate(),
        },
        auth            => {
            user => $user,
            pass => $pass
        }
    };
};

###############################################################################
# Handle 'create jobs' request.
#
post '/create' => http_basic_auth required => sub {
    # Hack required because of strange bug in Dancer2.
    # In theory serializer in request object should be set automatically but it doesn't.
    request->{serializer} = app->config->{serializer};
    my $jobs = request->data;

    my $web = creator->addon('web');
    $web->preprocessJobs($jobs);

    my ($user) = http_basic_auth_login;

    unless ($web->checkJobsAccess($user, $jobs)) {
        return {
            success => 0,
            error   => 'access denied'
        };
    }

    debug('Create jobs using web app by user \'' . $user . '\': ' . encode_json($jobs));

    my $observer = $web->hasIndividualObserver($user) ? 'u' . $user : 'web';
    my $error = creator->createJobs($jobs, {
        creator  => 'web',
        author   => $user,
        observer => $observer
    });

    if (defined($error)) {
        debug('Creating failed: ' . $error);
        return {
            success => 0,
            error   => $error
        };
    }

    return {
        success => 1
    };
};

post '/delay' => http_basic_auth required => sub {
    # Hack required because of strange bug in Dancer2.
    # In theory serializer in request object should be set automatically but it doesn't.
    request->{serializer} = app->config->{serializer};
    my $data = request->data;
    my $delay = $data->{delay};
    my $jobs = $data->{jobs};

    my $web = creator->addon('web');
    $web->preprocessJobs($jobs);
    $delay->{action} = DELAY_ACTION_CREATE;

    my ($user) = http_basic_auth_login;

    unless ($web->checkJobsAccess($user, $jobs) and $web->checkDelayAccess($user, $delay) and
        $web->checkJobsDelayAccess($user, $delay, $jobs)
    ) {
        return {
            success => 0,
            error   => 'access denied'
        };
    }

    debug('Delay jobs using web app by user \'' . $user . '\': ' . encode_json($jobs) .
        ', delay data: ' . encode_json($delay));

    my $observer = $web->hasIndividualObserver($user) ? 'u' . $user : 'web';
    my $error = creator->delayJobs($delay, $jobs, {
        creator  => 'web',
        author   => $user,
        observer => $observer
    });

    if (defined($error)) {
        debug('Delaying failed: ' . $error);
        return {
            success => 0,
            error   => $error
        };
    }

    return {
        success => 1
    };
};

###############################################################################
# Opening websocket connection.
# As 'Authorization' header not sent in such request, access is checked via 'user' and 'pass' query parameters.
# Observe private events here.
#
websocket_on_open sub {
    my $conn = shift;
    my $env = shift;

    creator->setBusy(1);

    my $query = parse_query_string($env->{'QUERY_STRING'});
    my $user = $query->{user} || '';
    my $pass = $query->{pass} || '';
    my $web = creator->addon('web');

    unless ($web->checkAuth($user, $pass)) {
        return;
    }

    $web->observePrivateEvents($conn, $user);

    creator->setBusy(0);
};

###############################################################################
# Initialize creator component before any request.
#
creator;

1;
