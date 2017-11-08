package AnyJob::Creator::App;

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;

set port => config->creator->{port} || 80;
set public_dir => path(app->location, 'web');
set static_handler => true;
set serializer => 'JSON';
set charset => 'UTF-8';

get '/' => sub {
        send_file '/index.html';
    };

get '/jobs' => sub {
        return {
            jobs  => config->getAllJobs(),
            props => config->getAllProps()
        };
    };

post '/create' => sub {
        # Хак, потребовавшийся из-за непонятного бага Dancer2.
        # По идее serializer в объекте request должен установиться автоматически, но не устанавливается.
        request->{serializer} = app->config->{serializer};
        my $jobs = request->data;

        if (defined(my $error = creator->createJobs($jobs))) {
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
