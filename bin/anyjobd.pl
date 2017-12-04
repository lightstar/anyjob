#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH DEFAULT_CONFIG_FILE injectPathIntoConstant);
use AnyJob::Config;
use AnyJob::Daemon;

BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : injectPathIntoConstant(DEFAULT_CONFIG_FILE);
my $daemon = AnyJob::Daemon->new(config => AnyJob::Config->new($configFile, 'anyjob'));
$daemon->run();

exit(0);
