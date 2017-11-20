#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Worker;

BEGIN {
    if ($ENV{ANYJOB_WORKER_LIB}) {
        require lib;
        lib->import($ENV{ANYJOB_WORKER_LIB});
    }
}

unless ($ENV{ANYJOB_ID}) {
    exit(1);
}

my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/current/anyjob.cfg";
my $worker = AnyJob::Worker->new(config => AnyJob::Config->new($configFile, "anyjob"));
$worker->run($ENV{ANYJOB_ID});

exit(0);
