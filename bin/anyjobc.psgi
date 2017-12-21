#!/usr/bin/perl

###############################################################################
# Executable for creator psgi web application which uses Dancer2 framework internally.
# You need to use psgi server that supports Dancer2, uses AnyEvent and that plugin Dancer2::Plugin::WebSocket supports.
# So for now the best (and maybe only) choice is Twiggy.
# Use 'plackup' program from 'Plack' perl module to launch it. For example:
# plackup --server Twiggy --host 127.0.0.1 --port 8080 --no-default-middleware /opt/anyjob/bin/anyjobc.psgi
#
# Author:       LightStar
# Created:      17.11.2017
# Last update:  12.12.2017
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use Plack::Builder;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Creator::App::Web;
use AnyJob::Creator::App::Slack;

###############################################################################
# Inline directory used by 'Inline' perl module.
#
BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

###############################################################################
# Mount creator Dancer2 applications.
#
builder {
        mount '/' => AnyJob::Creator::App::Web->to_app;
        mount(AnyJob::Creator::App::Web->websocket_mount);
        mount '/slack' => AnyJob::Creator::App::Slack->to_app;
    }
