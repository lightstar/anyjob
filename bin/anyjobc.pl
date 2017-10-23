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

    $creator->debug("Create job on node '" . $node . "' with type '" . $type .
        "' and params " . encode_json($params));

    $creator->createJob($node, $type, $params);
}

sub createTestJobSet {
    my $jobs = [
        {
            node   => "test",
            type   => "test",
            params => {
                test => "param1"
            }
        },
        {
            node   => "broadcast",
            type   => "test",
            params => {
                test => "param2"
            }
        }
    ];

    $creator->debug("Create jobset with jobs: " . encode_json($jobs));

    $creator->createJobSet($jobs);
}