#!/usr/bin/perl

###############################################################################
# Daemon executable where all controllers (including observers) are run.
# ANYJOB_NODE environment variable is required here and some others are optional.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  12.12.2017
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Daemon;

###############################################################################
# Inline directory used by 'Inline' perl module.
#
BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

AnyJob::Daemon->new()->run();

exit(0);
