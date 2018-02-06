#!/usr/bin/perl

###############################################################################
# Worker executable which is launched by daemon to run job in separate process.
# ANYJOB_NODE, ANYJOB_ID and ANYJOB_JOB environment variables are required here and some others are optional.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  06.02.2018
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Worker;

###############################################################################
# Import optional additional lib path if needed by specific worker module.
#
BEGIN {
    if (defined($ENV{ANYJOB_WORKER_LIB})) {
        lib->import($ENV{ANYJOB_WORKER_LIB});
    }
}

unless (defined($ENV{ANYJOB_ID}) and defined($ENV{ANYJOB_JOB})) {
    exit(1);
}

AnyJob::Worker->new()->run($ENV{ANYJOB_ID});

exit(0);
