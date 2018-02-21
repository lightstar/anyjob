package AnyJob::DateTime;

###############################################################################
# Functions related to manipulating with date and time.
#
# Author:       LightStar
# Created:      21.10.2017
# Last update:  21.02.2018
#

use strict;
use warnings;
use utf8;

use Time::Local;

use base 'Exporter';

our @EXPORT_OK = qw(
    DAYS_IN_MONTH
    DAYS_IN_MONTH_LEAP
    formatDateTime
    parseDateTime
    parsePeriod
    isValidDate
    isValidTime
    isLeapYear
    );

###############################################################################
# Hash where keys are months and values are numbers of days in corresponding month (in case this year is not leap one).
#
use constant DAYS_IN_MONTH => {
        1  => 31,
        2  => 28,
        3  => 31,
        4  => 30,
        5  => 31,
        6  => 30,
        7  => 31,
        8  => 31,
        9  => 30,
        10 => 31,
        11 => 30,
        12 => 31
    };

###############################################################################
# Hash where keys are months and values are numbers of days in corresponding month (in case this year is leap one).
#
use constant DAYS_IN_MONTH_LEAP => {
        1  => 31,
        2  => 29,
        3  => 31,
        4  => 30,
        5  => 31,
        6  => 30,
        7  => 31,
        8  => 31,
        9  => 30,
        10 => 31,
        11 => 30,
        12 => 31
    };

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

###############################################################################
# Parse date and time in provided string trying several formats:
# 1) 'DD-MM-YYYY HH:MM:SS'
# 2) 'YYYY-MM-DD HH:MM:SS' (symbols '-', ':' and ' ' are optional here)
# 3) 'DD-MM-YYY' (time is assumed to be '00:00:00')
# 4) 'YYYY-MM-DD' (symbol '-' is optional here and time is assumed to be '00:00:00')
# 5) 'HH:MM:SS' (date is assumed to be current date)
#
# If there are no errors, result hash will contain the following fields:
# 'year' - integer year.
# 'month' - integer month.
# 'day' - integer day.
# 'hour' - integer hour.
# 'minute' - integer minute.
# 'second' - integer second.
# 'unixTime' - integer time in unix timestamp format (i.e. number of seconds from 01-01-1970 00:00:00).
# 'dateTime' - string with date and time in format 'DD-MM-YYYY HH:MM:SS'.
# 'date' - string with date in format 'DD-MM-YYYY'.
# 'time' - string with time in format 'HH:MM:SS'.
#
# Arguments:
#     dateTime - input string with date and/or time.
# Returns:
#     hash with parsed date and time data or undef in case of parsing error.
#
sub parseDateTime {
    my $dateTime = shift;

    unless (defined($dateTime)) {
        return $dateTime;
    }

    my ($day, $month, $year, $hour, $minute, $second) =
        ($dateTime =~ /^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$/o);

    unless (defined($year)) {
        ($year, $month, $day, $hour, $minute, $second) =
            ($dateTime =~ /^(\d{4})-?(\d{2})-?(\d{2})\s*(\d{2}):?(\d{2}):?(\d{2})$/o);
    }

    unless (defined($year)) {
        ($day, $month, $year) = ($dateTime =~ /^(\d{2})-(\d{2})-(\d{4})$/o);
        ($hour, $minute, $second) = (0, 0, 0);
    }

    unless (defined($year)) {
        ($year, $month, $day) = ($dateTime =~ /^(\d{4})-?(\d{2})-?(\d{2})$/o);
        ($hour, $minute, $second) = (0, 0, 0);
    }

    unless (defined($year)) {
        ($hour, $minute, $second) = ($dateTime =~ /^(\d{2}):(\d{2}):(\d{2})$/o);
        if (defined($hour)) {
            ($day, $month, $year) = (localtime())[3, 4, 5];
            $year += 1900;
            $month++;
        }
    }

    unless (isValidDate($day, $month, $year) and isValidTime($hour, $minute, $second)) {
        return undef;
    }

    ($year, $month, $day, $hour, $minute, $second) = (int($year), int($month), int($day),
        int($hour), int($minute), int($second));

    return {
        year     => $year,
        month    => $month,
        day      => $day,
        hour     => $hour,
        minute   => $minute,
        second   => $second,
        unixTime => timelocal($second, $minute, $hour, $day, $month - 1, $year - 1900),
        dateTime => sprintf('%.2d-%.2d-%.4d %.2d:%.2d:%.2d', $day, $month, $year, $hour, $minute, $second),
        date     => sprintf('%.2d-%.2d-%.4d', $day, $month, $year),
        time     => sprintf('%.2d.:%.2d:%.2d', $hour, $minute, $second)
    };
}

###############################################################################
# Parse two strings with date and time assuming they are two opposite points of time interval.
# Function 'parseDateTime' is used for parsing and in case of any errors undef is returned.
# Undef is also returned if starting interval point is not less then the ending one.
#
# Arguments:
#     fromDateTime - input string with date and/or time of starting interval point.
#     toDateTime   - input string with date and/or time of ending interval point.
# Returns:
#     hash with parsed date and time data for starting interval point or undef in case of error.
#     hash with parsed date and time data for ending interval point or undef in case of error.
#
sub parsePeriod {
    my $fromDateTime = shift;
    my $toDateTime = shift;

    my $dataFrom = parseDateTime($fromDateTime);
    my $dataTo = parseDateTime($toDateTime);

    unless (defined($dataFrom) and defined($dataTo)) {
        return undef;
    }

    if ($dataFrom->{unixTime} >= $dataTo->{unixTime}) {
        return undef;
    }

    return ($dataFrom, $dataTo);
}

###############################################################################
# Check if provided date is valid.
#
# Arguments:
#     day   - integer day.
#     month - integer month.
#     year  - integer year.
# Returns:
#     0/1 flag. If set, date is valid.
#
sub isValidDate {
    my $day = shift;
    my $month = shift;
    my $year = shift;

    unless (defined($year) and defined($month) and defined($day) and
        $year =~ /^\d+$/o and $month =~ /^\d+$/o and $day =~ /^\d+$/o
    ) {
        return 0;
    }

    $day = int($day);
    $month = int($month);
    $year = int($year);

    unless ($year >= 1900 and $year <= 2100 and $month >= 1 and $month <= 12) {
        return 0;
    }

    my $daysInMonth = isLeapYear($year) ? DAYS_IN_MONTH_LEAP->{$month} : DAYS_IN_MONTH->{$month};

    unless ($day >= 1 and $day <= $daysInMonth) {
        return 0;
    }

    return 1;
}

###############################################################################
# Check if provided time is valid.
#
# Arguments:
#     hour    - integer hour.
#     minute  - integer minute.
#     second  - integer second.
# Returns:
#     0/1 flag. If set, time is valid.
#
sub isValidTime {
    my $hour = shift;
    my $minute = shift;
    my $second = shift;

    unless (defined($hour) and defined($minute) and defined($second) and
        $hour =~ /^\d+$/o and $minute =~ /^\d+$/o and $second =~ /^\d+$/o
    ) {
        return 0;
    }

    $hour = int($hour);
    $minute = int($minute);
    $second = int($second);

    unless ($hour >= 0 and $hour <= 23 and $minute >= 0 and $minute <= 59 and $second >= 0 and $second <= 59) {
        return 0;
    }

    return 1;
}

###############################################################################
# Check if provided year is the leap one.
#
# Arguments:
#     year  - integer year.
# Returns:
#     0/1 flag. If set, year is the leap one.
#
sub isLeapYear {
    my $year = shift;

    unless (defined($year) and $year =~ /^\d+$/o) {
        return 0;
    }

    $year = int($year);

    return (($year % 4 == 0) and (($year % 100 != 0) or ($year % 400 == 0))) ? 1 : 0;
}

1;
