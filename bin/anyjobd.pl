#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Daemon;

my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : '/opt/anyjob/etc/current/anyjob.cfg';
my $daemon = AnyJob::Daemon->new(config => AnyJob::Config->new($configFile, 'anyjob'));
$daemon->run();

exit(0);
