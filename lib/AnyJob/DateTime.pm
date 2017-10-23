package AnyJob::DateTime;

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    formatDateTime
    );

sub formatDateTime {
    my $time = shift;
    $time ||= time();

    my ($sec, $min, $hour, $day, $month, $year) = (localtime($time))[0 .. 5];
    $month++;
    $year += 1900;

    return sprintf("%.2d-%.2d-%.4d %.2d:%.2d:%.2d", $day, $month, $year, $hour, $min, $sec);
}

1;
