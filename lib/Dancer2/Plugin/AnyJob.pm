package Dancer2::Plugin::AnyJob;

use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Creator;

use Dancer2::Plugin;

my $creator;
sub anyjob {
    if (defined($creator)) {
        return $creator;
    }

    my $configFile = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
    $creator = AnyJob::Creator->new(config => AnyJob::Config->new($configFile, "anyjob"));
    return $creator;
}

plugin_keywords 'anyjob';

1;
