package AnyJob::Constants::States;

###############################################################################
# Constants used as job or jobset states.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  01.12.2017
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Initial state of any job or jobset.
#
use constant STATE_BEGIN => 'begin';

###############################################################################
# State for job which worker will set when it begins running it.
#
use constant STATE_RUN => 'run';

###############################################################################
# State for finished job.
# Actually finished jobs are cleaned immediately so this value is used inside jobsets only.
#
use constant STATE_FINISHED => 'finished';

our @EXPORT = qw(
    STATE_BEGIN
    STATE_RUN
    STATE_FINISHED
    );

1;
