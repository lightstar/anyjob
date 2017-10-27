#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Config;
use AnyJob::Creator;

my $configFile = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
my $creator = AnyJob::Creator->new(config => AnyJob::Config->new($configFile, "anyjob"));

createTestJob();
createTestJobSet();

sleep(60);

exit(0);

sub createTestJob {
    my $node = "test";
    my $type = "example";
    my $params = {
        param => "value"
    };
    my $props = {
        prop => "prop"
    };

    $creator->debug("Create job on node '" . $node . "' with type '" . $type .
        "', params " . encode_json($params)) . " and props " . encode_json($props);

    $creator->createJob($node, $type, $params, $props);
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

    $creator->debug("Create jobset with props " . encode_json($props) . "and jobs: " . encode_json($jobs));

    $creator->createJobSet($jobs, $props);
}