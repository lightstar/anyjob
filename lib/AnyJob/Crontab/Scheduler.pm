package AnyJob::Crontab::Scheduler;

###############################################################################
# Scheduler object which can determine time of next execution using crontab specification string.
# For details about specification string format see http://man7.org/linux/man-pages/man5/crontab.5.html
#
# Important exceptions from official crontab format are:
# 1) If both 'day of month' and 'day of week' fields are specified, scheduling time will be set to time when both
# fields are satisfied.
# 2) Named inputs such as '@yearly' will not work here, they should be mapped to real specification strings somewhere
# externally.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use POSIX qw(mktime);

use AnyJob::Constants::Crontab;
use AnyJob::Utils qw(requireModule);
use AnyJob::DateTime qw(DAYS_IN_MONTH DAYS_IN_MONTH_LEAP isLeapYear);

###############################################################################
# Construct new AnyJob::Crontab::Scheduler object.
#
# Arguments:
#     factory - AnyJob::Crontab::Factory object used to retrive instances of crontab-based set classes.
#     spec    - crontab specification string.
# Returns:
#     AnyJob::Crontab::Scheduler object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{factory})) {
        require Carp;
        Carp::confess('No factory');
    }

    unless (defined($self->{spec})) {
        require Carp;
        Carp::confess('No specification');
    }

    $self->init();

    return $self;
}

###############################################################################
# Parse specification string and initialize internal crontab-based sets.
# Throw exception if error in specification string is found.
#
sub init {
    my $self = shift;

    my @items = split(/\s+/, $self->{spec});

    while (scalar(@items) < CRONTAB_SETS_COUNT) {
        push @items, '*';
    }

    if (scalar(@items) != CRONTAB_SETS_COUNT) {
        require Carp;
        Carp::confess('Wrong specification');
    }

    my $factory = $self->{factory};
    my $monthSet = $factory->getSet(CRONTAB_MONTH_SET, $items[CRONTAB_MONTH_INDEX]);
    my $maxDay = $monthSet->getMaxDay();

    $self->{minutes} = $factory->getSet(CRONTAB_MINUTE_SET, $items[CRONTAB_MINUTE_INDEX])->getData();
    $self->{hours} = $factory->getSet(CRONTAB_HOUR_SET, $items[CRONTAB_HOUR_INDEX])->getData();
    $self->{days} = $factory->getSet(CRONTAB_DAY_SET, $items[CRONTAB_DAY_INDEX], $maxDay, {
        maxDay => $maxDay
    })->getData();
    $self->{months} = $monthSet->getData();
    $self->{weekDays} = $factory->getSet(CRONTAB_WEEKDAY_SET, $items[CRONTAB_WEEKDAY_INDEX])->getData();

    $self->{state} = {};
}

###############################################################################
# Calculate time of next execution.
#
# Returns:
#     integer time of next execution in unix timestamp format.
#
sub schedule {
    my $self = shift;

    my ($second, $minute, $hour, $day, $month, $year, $weekDay) = localtime(time() + 60);
    $month++;
    if ($weekDay == 0) {
        $weekDay = 7;
    }

    my $state = {
        minute  => $minute,
        hour    => $hour,
        day     => $day,
        month   => $month,
        year    => $year,
        weekDay => $weekDay
    };
    $self->{state} = $state;

    $self->yearUpdated();
    $self->monthUpdated();

    $self->searchMonth();
    $self->searchDay();
    $self->searchHour();
    $self->searchMinute();

    while ($self->searchWeekDay()) {
        $self->searchMonth();
        $self->searchDay();
    }

    return mktime(0, $state->{minute}, $state->{hour}, $state->{day}, $state->{month} - 1, $state->{year});
}

###############################################################################
# Search next month satisfying crontab specification and update internal scheduler state accordingly.
#
# Arguments:
#     startMonth - optional integer designating month from which search will be started. If omitted, month inside
#                  current state will be used.
#
sub searchMonth {
    my $self = shift;
    my $startMonth = shift;
    my $state = $self->{state};

    unless (defined($startMonth)) {
        $startMonth = $state->{month};
    }

    my ($month) = grep {$_ >= $startMonth} @{$self->{months}};
    unless (defined($month)) {
        $self->increaseYear();
        $self->updateMonth($self->{months}->[0]);
        return;
    }

    if ($state->{month} != $month) {
        $self->updateMonth($month);
    }
}

###############################################################################
# Search next day of month satisfying crontab specification and update internal scheduler state accordingly.
#
# Arguments:
#     startDay - optional integer designating day from which search will be started. If omitted, day inside
#                current state will be used.
#
sub searchDay {
    my $self = shift;
    my $startDay = shift;
    my $state = $self->{state};

    unless (defined($startDay)) {
        $startDay = $state->{day};
    }

    my ($day) = grep {$_ >= $startDay} @{$self->{days}};
    unless (defined($day)) {
        $self->searchMonth($state->{month} + 1);
        return;
    }

    if ($state->{day} != $day) {
        $self->updateDay($day);
    }
}

###############################################################################
# Search next hour satisfying crontab specification and update internal scheduler state accordingly.
#
# Arguments:
#     startHour - optional integer designating hour from which search will be started. If omitted, hour inside
#                 current state will be used.
#
sub searchHour {
    my $self = shift;
    my $startHour = shift;
    my $state = $self->{state};

    unless (defined($startHour)) {
        $startHour = $state->{hour};
    }

    my ($hour) = grep {$_ >= $startHour} @{$self->{hours}};
    unless (defined($hour)) {
        $self->searchDay($state->{day} + 1);
        return;
    }

    if ($state->{hour} != $hour) {
        $state->{hour} = $hour;
        $state->{minute} = $self->{minutes}->[0];
    }
}

###############################################################################
# Search next minute satisfying crontab specification and update internal scheduler state accordingly.
# Search will begin from minute inside current state.
#
sub searchMinute {
    my $self = shift;
    my $state = $self->{state};

    my ($minute) = grep {$_ >= $state->{minute}} @{$self->{minutes}};
    unless (defined($minute)) {
        $self->searchHour($state->{hour} + 1);
        return;
    }

    $state->{minute} = $minute;
}

###############################################################################
# Increase year inside current state by one.
#
sub increaseYear {
    my $self = shift;

    $self->{state}->{year}++;
    $self->yearUpdated();
}

###############################################################################
# Update fields inside current state which are dependent on the year value.
#
sub yearUpdated {
    my $self = shift;
    my $state = $self->{state};

    $state->{isLeapYear} = isLeapYear($state->{year});
}

###############################################################################
# Update month value inside current state. Day of month value will be updated automatically.
#
# Arguments:
#     month - integer new month value.
#
sub updateMonth {
    my $self = shift;
    my $month = shift;
    my $state = $self->{state};

    $state->{month} = $month;
    $self->monthUpdated();

    $self->updateDay($self->{days}->[0]);
}

###############################################################################
# Update fields inside current state which are dependent on the month value.
#
sub monthUpdated {
    my $self = shift;
    my $state = $self->{state};

    $state->{daysInMonth} = $state->{isLeapYear} ?
        DAYS_IN_MONTH_LEAP->{$state->{month}} :
        DAYS_IN_MONTH->{$state->{month}};
}

###############################################################################
# Update day of month value inside current state. Other dependent state fields will be updated automatically.
#
# Arguments:
#     day - integer new day of month value.
#
sub updateDay {
    my $self = shift;
    my $day = shift;
    my $state = $self->{state};

    unless ($self->isDayValid($day)) {
        $self->searchMonth($state->{month} + 1);
        return;
    }

    $state->{day} = $day;
    $state->{hour} = $self->{hours}->[0];
    $state->{minute} = $self->{minutes}->[0];

    $state->{weekDay} = (localtime(mktime(0, 0, 0, $state->{day}, $state->{month} - 1, $state->{year})))[6];
    if ($state->{weekDay} == 0) {
        $state->{weekDay} = 7;
    }
}

###############################################################################
# Check if specified day of month is valid for current month value.
#
# Arguments:
#     day - integer day of month value.
# Returns:
#     0/1 flag. If set, day value is valid, otherwise it is not.
#
sub isDayValid {
    my $self = shift;
    my $day = shift;

    return $day <= $self->{state}->{daysInMonth} ? 1 : 0;
}

###############################################################################
# Search next week day satisfying crontab specification and update internal scheduler state accordingly.
# Search will begin from week day inside current state.
#
# Returns:
#     0/1 flag. If set, day value was changed and thereby month and day searching must be performed again.
#
sub searchWeekDay {
    my $self = shift;
    my $state = $self->{state};

    my ($weekDay) = grep {$_ >= $state->{weekDay}} @{$self->{weekDays}};
    unless (defined($weekDay)) {
        $weekDay = $self->{weekDays}->[0];
    }

    my $daysDelta = $weekDay >= $state->{weekDay} ?
        $weekDay - $state->{weekDay} :
        7 - $state->{weekDay} + $weekDay;

    if ($daysDelta == 0) {
        return 0;
    }

    my ($day, $month, $year) = (localtime(mktime(0, 0, 0, $state->{day} + $daysDelta,
        $state->{month} - 1, $state->{year})))[3 .. 5];
    $month++;

    if ($state->{year} != $year) {
        $state->{year} = $year;
        $self->yearUpdated();
    }

    if ($state->{month} != $month) {
        $state->{month} = $month;
        $self->monthUpdated();
    }

    $state->{day} = $day;
    $state->{hour} = $self->{hours}->[0];
    $state->{minute} = $self->{minutes}->[0];
    $state->{weekDay} = $weekDay;

    return 1;
}

1;
