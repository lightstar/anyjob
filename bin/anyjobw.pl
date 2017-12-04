#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CONFIG_FILE injectPathIntoConstant);
use AnyJob::Config;
use AnyJob::Worker;

BEGIN {
    if (defined($ENV{ANYJOB_WORKER_LIB})) {
        lib->import($ENV{ANYJOB_WORKER_LIB});
    }
}

unless ($ENV{ANYJOB_ID}) {
    exit(1);
}

my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : injectPathIntoConstant(DEFAULT_CONFIG_FILE);
my $worker = AnyJob::Worker->new(config => AnyJob::Config->new($configFile, 'anyjob'));
$worker->run($ENV{ANYJOB_ID});

exit(0);
