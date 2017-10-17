#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Controller;

my $config_file = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
my $controller = AnyJob::Controller->new(config => AnyJob::Config->new($config_file, "anyjob"));

$controller->run();

exit(0);
