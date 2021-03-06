package AnyJob::Constants::Delay;

###############################################################################
# Constants related to delayed works.
#
# Author:       LightStar
# Created:      29.05.2018
# Last update:  29.01.2019
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Name of 'create delayed work' action.
#
use constant DELAY_ACTION_CREATE => 'create';

###############################################################################
# Name of 'update delayed work' action.
#
use constant DELAY_ACTION_UPDATE => 'update';

###############################################################################
# Name of 'schedule delayed work' action.
#
use constant DELAY_ACTION_SCHEDULE => 'schedule';

###############################################################################
# Name of 'skip delayed work' action.
#
use constant DELAY_ACTION_SKIP => 'skip';

###############################################################################
# Name of 'pause delayed work' action.
#
use constant DELAY_ACTION_PAUSE => 'pause';

###############################################################################
# Name of 'resume delayed work' action.
#
use constant DELAY_ACTION_RESUME => 'resume';

###############################################################################
# Name of 'delete delayed work' action.
#
use constant DELAY_ACTION_DELETE => 'delete';

###############################################################################
# Name of 'get delayed works' action.
#
use constant DELAY_ACTION_GET => 'get';

###############################################################################
# Hash with all delay actions supported by delay controller.
# Each key here is string action name and values are always equal to '1'.
use constant DELAY_REAL_ACTIONS => { map {$_ => 1} (DELAY_ACTION_CREATE, DELAY_ACTION_UPDATE, DELAY_ACTION_DELETE,
    DELAY_ACTION_GET) };

###############################################################################
# Hash with actions which need to be written explicitly in command string.
# Each key here is string action name and values are always equal to '1'.
#
use constant DELAY_EXPLICIT_ACTIONS => { map {$_ => 1} (DELAY_ACTION_UPDATE, DELAY_ACTION_SCHEDULE, DELAY_ACTION_SKIP,
    DELAY_ACTION_PAUSE, DELAY_ACTION_RESUME, DELAY_ACTION_DELETE, DELAY_ACTION_GET) };

###############################################################################
# Hash with actions which need job data to process.
# Each key here is string action name and values are always equal to '1'.
#
use constant DELAY_JOB_ACTIONS => { map {$_ => 1} (DELAY_ACTION_CREATE, DELAY_ACTION_UPDATE) };

###############################################################################
# Hash with actions which need string summary of delayed work.
# Each key here is string action name and values are always equal to '1'.
#
use constant DELAY_ACTIONS_WITH_SUMMARY => { map {$_ => 1} (DELAY_ACTION_CREATE, DELAY_ACTION_UPDATE) };

###############################################################################
# Hash with meta actions which must be transformed to real ones actually supported by delay controller.
# Each key here is string meta action name and values are corresponding real action names.
#
use constant DELAY_META_ACTIONS => {
    DELAY_ACTION_SCHEDULE() => DELAY_ACTION_UPDATE,
    DELAY_ACTION_SKIP()     => DELAY_ACTION_UPDATE,
    DELAY_ACTION_PAUSE()    => DELAY_ACTION_UPDATE,
    DELAY_ACTION_RESUME()   => DELAY_ACTION_UPDATE
};

###############################################################################
# Timeout in seconds of waiting result from queue for 'get delayed works' action.
#
use constant DELAY_GET_TIMEOUT => 10;

###############################################################################
# Default delayed work author name.
#
use constant DELAY_AUTHOR_UNKNOWN => 'unknown';

our @EXPORT = qw(
    DELAY_ACTION_CREATE
    DELAY_ACTION_UPDATE
    DELAY_ACTION_SCHEDULE
    DELAY_ACTION_SKIP
    DELAY_ACTION_PAUSE
    DELAY_ACTION_RESUME
    DELAY_ACTION_DELETE
    DELAY_ACTION_GET
    DELAY_REAL_ACTIONS
    DELAY_EXPLICIT_ACTIONS
    DELAY_JOB_ACTIONS
    DELAY_ACTIONS_WITH_SUMMARY
    DELAY_META_ACTIONS
    DELAY_GET_TIMEOUT
    DELAY_AUTHOR_UNKNOWN
);

1;
