#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Config;
use AnyJob::Creator;

my $config_file = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
my $creator = AnyJob::Creator->new(config => AnyJob::Config->new($config_file, "anyjob"));

createTestJob();
createTestJobSet();

sleep(60);

exit(0);

sub createTestJob {
    my $node = "test";
    my $type = "test";
    my $params = {
        test => "param"
    };
    my $props = {
        test_prop => "prop"
    };

    $creator->debug("Create job on node '" . $node . "' with type '" . $type .
        "', params " . encode_json($params)) . " and props " . encode_json($props);

    $creator->createJob($node, $type, $params, $props);
}

sub createTestJobSet {
    my $props = {
        test_prop => "prop_jobset"
    };
    my $jobs = [
        {
            node   => "test",
            type   => "test",
            params => {
                test => "param1"
            },
            props  => {
                test_prop => "prop1"
            }
        },
        {
            node   => "broadcast",
            type   => "test",
            params => {
                test => "param2"
            },
            props  => {
                test_prop => "prop2"
            }
        }
    ];

    $creator->debug("Create jobset with props " . encode_json($props) . "and jobs: " . encode_json($jobs));

    $creator->createJobSet($jobs, $props);
}