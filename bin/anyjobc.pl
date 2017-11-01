#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use Dancer2;

use AnyJob::Creator::App;

start;

exit(0);
