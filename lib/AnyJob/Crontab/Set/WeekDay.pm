package AnyJob::Crontab::Set::WeekDay;

###############################################################################
# Set of week days used in crontab scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Crontab qw(CRONTAB_WEEKDAY_RANGE CRONTAB_WEEKDAY_MAPPER);

use base 'AnyJob::Crontab::Set::Base';

###############################################################################
# Construct new AnyJob::Crontab::Set::WeekDay object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     filter - optional function used to additionally filter out week days from set.
# Returns:
#     AnyJob::Crontab::Set::WeekDay object.
#
sub new {
    my $class = shift;
    my %args = @_;

    $args{range} = CRONTAB_WEEKDAY_RANGE;
    $args{mapper} = CRONTAB_WEEKDAY_MAPPER;

    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
