#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use Plack::Builder;

use AnyJob::App::Creator;
use AnyJob::App::Observer;

builder {
        mount '/' => AnyJob::App::Creator->to_app;
        mount(AnyJob::App::Observer->websocket_mount);
    }
