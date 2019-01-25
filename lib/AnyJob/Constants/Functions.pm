package AnyJob::Constants::Functions;

###############################################################################
# Constants with generally-used function objects.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Empty function which does nothing.
#
use constant EMPTY_FN => sub {};

###############################################################################
# Identity function used to map value to itself.
#
use constant IDENTITY_FN => sub {$_[0]};

###############################################################################
# Function which always returns 'true' used for 'always true' filters.
#
use constant TRUE_FN => sub {1};

our @EXPORT = qw(
    EMPTY_FN
    IDENTITY_FN
    TRUE_FN
);

1;
