package AnyJob::Crontab::Set::Minute;

###############################################################################
# Set of minutes used in crontab scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Crontab qw(CRONTAB_MINUTE_RANGE);

use base 'AnyJob::Crontab::Set::Base';

###############################################################################
# Construct new AnyJob::Crontab::Set::Minute object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     filter - optional function used to additionally filter out minutes from set.
# Returns:
#     AnyJob::Crontab::Set::Minute object.
#
sub new {
    my $class = shift;
    my %args = @_;

    $args{range} = CRONTAB_MINUTE_RANGE;
    $args{mapper} = undef;

    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
