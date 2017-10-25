#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Config;
use AnyJob::Worker;

my $id = $ENV{ANYJOB_ID};
unless ($id) {
    exit(1);
}

my $config_file = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
my $worker = AnyJob::Worker->new(config => AnyJob::Config->new($config_file, "anyjob"));
my $job = $worker->getJob($id);

unless ($job) {
    exit(1);
}

$worker->debug("Perform job '" . $id . "' on node '" . $worker->node . "': " . encode_json($job));
$worker->sendProgress($id, { state => "run" });

sleep(2);

$worker->sendLog($id, "Step 1");

sleep(5);

$worker->sendLog($id, "Step 2");

sleep(10);

$worker->debug("Finish performing job '" . $id . "'");
$worker->sendProgress($id, { success => 1, message => "done" });

exit(0);
