#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || '/opt/anyjob/lib');
use strict;
use warnings;
use utf8;

use Plack::Builder;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Creator::App::Web;
use AnyJob::Creator::App::Slack;

BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

builder {
        mount '/' => AnyJob::Creator::App::Web->to_app;
        mount(AnyJob::Creator::App::Web->websocket_mount);
        mount '/slack' => AnyJob::Creator::App::Slack->to_app;
    }
