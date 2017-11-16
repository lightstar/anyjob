package AnyJob::App::Creator;

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;
use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;

set public_dir => path(app->location, 'web');
set static_handler => true;
set serializer => 'JSON';
set charset => 'UTF-8';
set plugins => {
        'Auth::HTTP::Basic::DWIW' => {
            realm => 'AnyJob'
        }
    };

http_basic_auth_set_check_handler sub {
        my $user = shift;
        my $pass = shift;
        return config->checkAuth($user, $pass);
    };

get '/' => http_basic_auth required => sub {
            send_file '/index.html';
        };

get '/config' => http_basic_auth required => sub {
            my ($user, $pass) = http_basic_auth_login;
            return {
                jobs     => config->getAllJobs(),
                props    => config->getAllProps(),
                observer => {
                    eventTemplate => creator->getAppEventTemplate(),
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

            my ($user) = http_basic_auth_login;

            if (defined(my $error = creator->createJobs($jobs, "u" . $user))) {
                return {
                    success => 0,
                    error   => $error
                };
            }

            return {
                success => 1
            };
        };

1;
