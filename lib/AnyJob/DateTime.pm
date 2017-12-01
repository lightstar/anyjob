package AnyJob::DateTime;

###############################################################################
# Functions related to manipulating with date and time.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  01.12.2017
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    formatDateTime
    );

###############################################################################
# Format provided unix time (or current time) using standart scheme 'DD-MM-YYYY HH:MM:SS'.
#
# Arguments:
#     time - integer unix time. Current time will be substituted if 0 or undef.
# Returns:
#     string formatted datetime.
#
sub formatDateTime {
    my $time = shift;
    $time ||= time();

    my ($sec, $min, $hour, $day, $month, $year) = (localtime($time))[0 .. 5];
    $month++;
    $year += 1900;

    return sprintf('%.2d-%.2d-%.4d %.2d:%.2d:%.2d', $day, $month, $year, $hour, $min, $sec);
}

1;
