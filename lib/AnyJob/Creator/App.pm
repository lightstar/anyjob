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

get '/test' => sub {
        createTestJob();
        createTestJobSet();
        forward '/';
    };

get '/jobs' => sub {
        return {
            jobs => creator->getAllJobs(),
            props => creator->getAllProps()
        };
    };

sub createTestJob {
    my $node = "test";
    my $type = "example";
    my $params = {
        param => "value"
    };
    my $props = {
        prop => "prop"
    };

    debug("Create job on node '" . $node . "' with type '" . $type .
        "', params " . encode_json($params)) . " and props " . encode_json($props);

    creator->createJob($node, $type, $params, $props);
}

sub createTestJobSet {
    my $props = {
        prop => "prop"
    };
    my $jobs = [
        {
            node   => "test",
            type   => "example",
            params => {
                param => "value1"
            },
            props  => {
                prop => "prop1"
            }
        },
        {
            node   => "broadcast",
            type   => "example",
            params => {
                param => "value2"
            },
            props  => {
                prop => "prop2"
            }
        }
    ];

    debug("Create jobset with props " . encode_json($props) . "and jobs: " . encode_json($jobs));

    creator->createJobSet($jobs, $props);
}

1;
