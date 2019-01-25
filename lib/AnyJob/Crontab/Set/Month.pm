package AnyJob::Crontab::Set::Month;

###############################################################################
# Set of months used in crontab scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Crontab qw(CRONTAB_MONTH_RANGE CRONTAB_MONTH_MAPPER);
use AnyJob::DateTime qw(DAYS_IN_MONTH_LEAP);

use base 'AnyJob::Crontab::Set::Base';

###############################################################################
# Construct new AnyJob::Crontab::Set::Month object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     filter - optional function used to additionally filter out months from set.
# Returns:
#     AnyJob::Crontab::Set::Month object.
#
sub new {
    my $class = shift;
    my %args = @_;

    $args{range} = CRONTAB_MONTH_RANGE;
    $args{mapper} = CRONTAB_MONTH_MAPPER;

    my $self = $class->SUPER::new(%args);
    return $self;
}

###############################################################################
# Get total maximum of day number among all months in set.
#
# Returns:
#     integer maximum day.
#
sub getMaxDay {
    my $self = shift;

    if (exists($self->{maxDay})) {
        return $self->{maxDay};
    }

    my $maxDay = 0;
    foreach my $month (@{$self->{list}}) {
        if ($maxDay < DAYS_IN_MONTH_LEAP->{$month}) {
            $maxDay = DAYS_IN_MONTH_LEAP->{$month};
        }
    }

    $self->{maxDay} = $maxDay;
    return $maxDay;
}

1;
