#!/usr/bin/perl

###############################################################################
# Tool used to force exit from some semaphore by some client. It accepts following arguments:
# semaphore name, client name and optional flag 'r' to exit by reading client.
#
# Author:       LightStar
# Created:      19.12.2018
# Last update:  19.12.2018
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Tool;

###############################################################################
# Inline directory used by 'Inline' perl module.
#
BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

if (scalar(@ARGV) < 2) {
    print 'Usage: semexit <semaphore> <client> [r]' . "\n";
    exit(1);
}

my $tool = AnyJob::Tool->new();

if (scalar(@ARGV) > 2 and $ARGV[2] eq 'r') {
    unless ($tool->getSemaphore($ARGV[0])->exitRead($ARGV[1])) {
        print 'Reading client \'' . $ARGV[1] . '\' is not holding semaphore \'' . $ARGV[0] . '\'' . "\n";
    } else {
        print 'Reading client \'' . $ARGV[1] . '\' exited from semaphore \'' . $ARGV[0] . '\'' . "\n";
    }
} else {
    unless ($tool->getSemaphore($ARGV[0])->exit($ARGV[1])) {
        print 'Client \'' . $ARGV[1] . '\' is not holding semaphore \'' . $ARGV[0] . '\'' . "\n";
    } else {
        print 'Client \'' . $ARGV[1] . '\' exited from semaphore \'' . $ARGV[0] . '\'' . "\n";
    }
}

exit(0);

1;
