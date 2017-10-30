package AnyJob::Creator::App;

use strict;
use warnings;
use utf8;

use Dancer2;
use Dancer2::Plugin::AnyJob;

set port => anyjob->config->creator->{port} || 80;
set public_dir => path(app->location, 'web');
set static_handler => true;

get '/' => sub {
        createTestJob();
        createTestJobSet();
        send_file '/index.html';
    };

start;

sub createTestJob {
    my $node = "test";
    my $type = "example";
    my $params = {
        param => "value"
    };
    my $props = {
        prop => "prop"
    };

    anyjob->debug("Create job on node '" . $node . "' with type '" . $type .
        "', params " . encode_json($params)) . " and props " . encode_json($props);

    anyjob->createJob($node, $type, $params, $props);
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

    anyjob->debug("Create jobset with props " . encode_json($props) . "and jobs: " . encode_json($jobs));

    anyjob->createJobSet($jobs, $props);
}

1;
