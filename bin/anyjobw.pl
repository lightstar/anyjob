#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Worker;

BEGIN {
    if (defined($ENV{ANYJOB_WORKER_LIB})) {
        lib->import($ENV{ANYJOB_WORKER_LIB});
    }
}

unless (defined($ENV{ANYJOB_ID})) {
    exit(1);
}

AnyJob::Worker->new()->run($ENV{ANYJOB_ID});

exit(0);
