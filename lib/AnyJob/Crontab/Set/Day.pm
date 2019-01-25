package AnyJob::Crontab::Set::Day;

###############################################################################
# Set of month days used in crontab scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Crontab qw(CRONTAB_DEFAULT_MAX_DAY CRONTAB_DAY_RANGES);

use base 'AnyJob::Crontab::Set::Base';

###############################################################################
# Construct new AnyJob::Crontab::Set::Day object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     maxDay - optional integer used as maximum day number which is generally dependent on month and year.
#              By default it is 31.
#     filter - optional function used to additionally filter out days from set.
# Returns:
#     AnyJob::Crontab::Set::Day object.
#
sub new {
    my $class = shift;
    my %args = @_;

    my $maxDay = $args{maxDay};
    unless (defined($maxDay) and exists(CRONTAB_DAY_RANGES->{$maxDay})) {
        $maxDay = CRONTAB_DEFAULT_MAX_DAY;
    }

    $args{range} = CRONTAB_DAY_RANGES->{$maxDay};
    $args{mapper} = undef;

    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
