package Dancer2::Plugin::AnyJob;

###############################################################################
# Plugin used to integrate AnyJob creator component with Dancer2 web application.
#
# Author:       LightStar
# Created:      30.10.2017
# Last update:  08.12.2017
#

use strict;
use warnings;
use utf8;

use AnyJob::Creator::App;

use Dancer2::Plugin;

our $VERSION = '0.1';

###############################################################################
# Register hooks for every request.
# These hooks set 'busy' flag in creator during request execution to indicate that it is not safe to shutdown.
#
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

###############################################################################
# Instantiate and retrieve creator component object.
#
# Returns:
#     AnyJob::Creator::App object.
#
my $creator;
sub creator {
    unless (defined($creator)) {
        $creator = AnyJob::Creator::App->new();
    }
    return $creator;
}

###############################################################################
# Define plugin keywords to use within Dancer2 application.
#
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
