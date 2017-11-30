package AnyJob::Creator::Shutdown;

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT = qw(isShutdown);

my $isShutdown = 0;

$SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$isShutdown = 1};

sub isShutdown {
    return $isShutdown;
}

1;
