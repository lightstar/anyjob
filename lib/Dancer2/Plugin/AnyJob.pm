package Dancer2::Plugin::AnyJob;

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_CONFIG_FILE injectPathIntoConstant);
use AnyJob::Config;
use AnyJob::Creator::App;

use Dancer2::Plugin;

our $VERSION = '0.1';

sub BUILD {
    my $plugin = shift;

    $plugin->app->add_hook(Dancer2::Core::Hook->new(
        name => 'before',
        code => sub {
            $plugin->creator->setBusy(1);
        }
    ));

    $plugin->app->add_hook(Dancer2::Core::Hook->new(
        name => 'after',
        code => sub {
            $plugin->creator->setBusy(0);
        }
    ));
}

my $creator;
sub creator {
    if (defined($creator)) {
        return $creator;
    }

    my $configFile = $ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : injectPathIntoConstant(DEFAULT_CONFIG_FILE);
    $creator = AnyJob::Creator::App->new(config => AnyJob::Config->new($configFile, 'anyjob'));

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
