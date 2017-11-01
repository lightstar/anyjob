package Dancer2::Plugin::AnyJob;

use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Creator;

use Dancer2::Plugin;

our $VERSION = "0.1";

my $creator;
sub creator {
    if (defined($creator)) {
        return $creator;
    }

    my $configFile = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
    $creator = AnyJob::Creator->new(config => AnyJob::Config->new($configFile, "anyjob"));
    return $creator;
}

sub config {
    return creator->config;
}

sub debug {
    creator->debug($_[1]);
}

sub error {
    creator->error($_[1]);
}

plugin_keywords qw(creator config debug error);

1;
