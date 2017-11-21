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

    my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : '/opt/anyjob/etc/current/anyjob.cfg';
    $creator = AnyJob::Creator->new(config => AnyJob::Config->new($configFile, 'anyjob'));

    return $creator;
}

plugin_keywords
    'creator',
    'config' => sub {
        return creator->config;
    },
    'debug'  => sub {
        return creator->debug($_[1]);
    },
    'error'  => sub {
        return creator->error($_[1]);
    };

1;
