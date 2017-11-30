#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Creator;

my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : '/opt/anyjob/etc/current/anyjob.cfg';
my $creator = AnyJob::Creator->new(config => AnyJob::Config->new($configFile, 'anyjob'));

print $creator->addon('console')->create(\@ARGV) . "\n";

exit(0);
