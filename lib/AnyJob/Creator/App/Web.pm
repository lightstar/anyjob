package AnyJob::Creator::App::Web;

use strict;
use warnings;
use utf8;

use AnyEvent;
use CGI::Deurl::XS qw(parse_query_string);

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;
use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;
use Dancer2::Plugin::WebSocket;

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

http_basic_auth_set_check_handler sub {
        my $user = shift;
        my $pass = shift;
        return creator->addon('web')->checkAuth($user, $pass);
    };

get '/' => http_basic_auth required => sub {
            send_file '/index.html';
        };

get '/config' => http_basic_auth required => sub {
            my ($user, $pass) = http_basic_auth_login;
            return {
                jobs     => config->getAllJobs(),
                props    => config->getProps(),
                observer => {
                    eventTemplate => creator->addon('web')->getEventTemplate(),
                },
                auth     => {
                    user => $user,
                    pass => $pass
                }
            };
        };

post '/create' => http_basic_auth required => sub {
            # Хак, потребовавшийся из-за непонятного бага Dancer2.
            # По идее serializer в объекте request должен установиться автоматически, но не устанавливается.
            request->{serializer} = app->config->{serializer};
            my $jobs = request->data;
            creator->addon('web')->preprocessJobs($jobs);

            my ($user) = http_basic_auth_login;

            debug('Create jobs using web app by user \'' . $user . '\': ' . encode_json($jobs));

            if (defined(my $error = creator->createJobs($jobs, { observer => 'u' . $user }))) {
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

websocket_on_open sub {
        my $conn = shift;
        my $env = shift;

        my $query = parse_query_string($env->{'QUERY_STRING'});
        my $user = $query->{user} || '';
        my $pass = $query->{pass} || '';

        unless (creator->addon('web')->checkAuth($user, $pass)) {
            return;
        }

        my $config = config->section('web') || {};
        my $delay = $config->{observer_delay} || 1;
        my $timer = AnyEvent->timer(after => $delay, interval => $delay, cb => sub {
                my $events = creator->receivePrivateEvents('u' . $user);
                if (scalar(@$events)) {
                    $conn->send($events);
                }
            });
        $conn->on(close => sub {
                undef $timer;
            });
    };

1;
