package AnyJob::Constants::Defaults;

###############################################################################
# Constants used as some default values.
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
# Default limit when retrieving data.
#
use constant DEFAULT_LIMIT => 10;

###############################################################################
# Default delay in seconds between processing.
#
use constant DEFAULT_DELAY => 1;

###############################################################################
# Default timeout in seconds before some object will be expired and cleaned out.
#
use constant DEFAULT_CLEAN_TIMEOUT => 3600;

###############################################################################
# Default delay in seconds between checking objects expire status.
#
use constant DEFAULT_CLEAN_DELAY => 60;

###############################################################################
# Default pid file for daemon.
#
use constant DEFAULT_PIDFILE => '/var/run/anyjobd.pid';

our @EXPORT = qw(
    DEFAULT_LIMIT
    DEFAULT_DELAY
    DEFAULT_CLEAN_TIMEOUT
    DEFAULT_CLEAN_DELAY
    DEFAULT_PIDFILE
    );

1;
