package AnyJob::Crontab::Set::Hour;

###############################################################################
# Set of hours used in crontab scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Crontab qw(CRONTAB_HOUR_RANGE);

use base 'AnyJob::Crontab::Set::Base';

###############################################################################
# Construct new AnyJob::Crontab::Set::Hour object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     filter - optional function used to additionally filter out hours from set.
# Returns:
#     AnyJob::Crontab::Set::Hour object.
#
sub new {
    my $class = shift;
    my %args = @_;

    $args{range} = CRONTAB_HOUR_RANGE;
    $args{mapper} = undef;

    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
