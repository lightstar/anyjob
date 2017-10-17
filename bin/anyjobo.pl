#!/usr/bin/perl

use lib ($ENV{ANYJOB_LIB} || "/opt/anyjob/lib");
use strict;
use warnings;
use utf8;

use JSON::XS;
use Time::HiRes qw(usleep);

use AnyJob::Config;
use AnyJob::Observer;

my $config_file = $ARGV[0] || ($ENV{ANYJOB_CONF} ? $ENV{ANYJOB_CONF} : "/opt/anyjob/etc/anyjob.cfg");
my $observer = AnyJob::Observer->new(config => AnyJob::Config->new($config_file, "anyjob"));
my $name = "test";

while (1) {
    while (my $event = $observer->receiveEvent($name)) {
        $observer->debug("Received event '" . $event->{event} . "' on node '" . $event->{node} . "': " . encode_json($event));
    }
    usleep(1000000);
}

exit(0);
