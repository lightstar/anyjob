package Dancer2::Plugin::AnyJob;

use strict;
use warnings;
use utf8;

use AnyJob::Config;
use AnyJob::Utils qw(moduleName requireModule);

use Dancer2::Plugin;

our $VERSION = "0.1";

my $creator;
sub creator {
    my $plugin = shift;

    if (defined($creator)) {
        return $creator;
    }

    my $module = 'AnyJob::Creator';
    if (defined($plugin->config->{creatorName})) {
        $module .= '::' . moduleName($plugin->config->{creatorName});
    }
    requireModule($module);

    my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : '/opt/anyjob/etc/current/anyjob.cfg';
    $creator = $module->new(config => AnyJob::Config->new($configFile, 'anyjob'));

    return $creator;
}

plugin_keywords
    'creator',
    'config' => sub {
        return creator($_[0])->config;
    },
    'debug'  => sub {
        return creator($_[0])->debug($_[1]);
    },
    'error'  => sub {
        return creator($_[0])->error($_[1]);
    };

1;
