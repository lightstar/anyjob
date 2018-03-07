#!/usr/bin/perl

###############################################################################
# Worker daemon executable which is launched by main daemon to execute jobs.
# ANYJOB_NODE and ANYJOB_WORKER environment variables are required here and some others are optional.
#
# Author:       LightStar
# Created:      05.03.2018
# Last update:  06.03.2018
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Worker::Daemon;

###############################################################################
# Import optional additional lib path if needed by specific worker modules.
#
BEGIN {
    if (defined($ENV{ANYJOB_WORKER_LIB})) {
        lib->import($ENV{ANYJOB_WORKER_LIB});
    }
}

unless (defined($ENV{ANYJOB_WORKER})) {
    exit(1);
}

AnyJob::Worker::Daemon->new(name => $ENV{ANYJOB_WORKER})->run();

exit(0);
