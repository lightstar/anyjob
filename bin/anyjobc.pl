#!/usr/bin/perl

###############################################################################
# Creator executable which can be launched manually from console (or by using cron for example) to create job.
# All arguments are passed to AnyJob::Creator::Addon::Console module and then parsed by AnyJob::Creator::Parser,
# so look there for details.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  01.03.2018
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Creator;

###############################################################################
# Inline directory used by 'Inline' perl module.
#
BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

my $creator = AnyJob::Creator->new();

my $console = $creator->addon('console');
print $console->create(\@ARGV) . "\n";
$console->stop();

exit(0);
