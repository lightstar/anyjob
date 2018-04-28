package AnyJob::Constants::Semaphore;

###############################################################################
# Constants used for semaphore management.
#
# Author:       LightStar
# Created:      05.04.2018
# Last update:  28.04.2018
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Semaphore 'wrap' mode for entity.
#
use constant SEMAPHORE_MODE_WRAP => 'wrap';

###############################################################################
# Semaphore 'reading wrap' mode for entity.
#
use constant SEMAPHORE_MODE_WRAP_READ => 'wrapRead';

###############################################################################
# Semaphore 'enter' mode for entity.
#
use constant SEMAPHORE_MODE_ENTER => 'enter';

###############################################################################
# Semaphore 'reading enter' mode for entity.
#
use constant SEMAPHORE_MODE_ENTER_READ => 'enterRead';

###############################################################################
# Semaphore 'exit' mode for entity.
#
use constant SEMAPHORE_MODE_EXIT => 'exit';

###############################################################################
# Semaphore 'reading exit' mode for entity.
#
use constant SEMAPHORE_MODE_EXIT_READ => 'exitRead';

###############################################################################
# Semaphore 'exit at start' mode for entity.
#
use constant SEMAPHORE_MODE_EXIT_AT_START => 'exitAtStart';

###############################################################################
# Semaphore 'reading exit at start' mode for entity.
#
use constant SEMAPHORE_MODE_EXIT_READ_AT_START => 'exitReadAtStart';

###############################################################################
# Semaphore 'enter' action for entity.
#
use constant SEMAPHORE_ACTION_ENTER => 'enter';

###############################################################################
# Semaphore 'reading enter' action for entity.
#
use constant SEMAPHORE_ACTION_ENTER_READ => 'enterRead';

###############################################################################
# Semaphore 'exit' action for entity.
#
use constant SEMAPHORE_ACTION_EXIT => 'exit';

###############################################################################
# Semaphore 'reading exit' action for entity.
#
use constant SEMAPHORE_ACTION_EXIT_READ => 'exitRead';

###############################################################################
# Semaphore client 'entity' mode.
#
use constant SEMAPHORE_CLIENT_MODE_ENTITY => 'entity';

###############################################################################
# Semaphore client 'jobset' mode.
#
use constant SEMAPHORE_CLIENT_MODE_JOBSET => 'jobset';

###############################################################################
# Semaphore client 'single' mode.
#
use constant SEMAPHORE_CLIENT_MODE_SINGLE => 'single';

###############################################################################
# Array with semaphore sequence used before entity process.
#
use constant SEMAPHORE_RUN_SEQUENCE => [
    {
        mode   => SEMAPHORE_MODE_WRAP,
        action => SEMAPHORE_ACTION_ENTER
    },
    {
        mode   => SEMAPHORE_MODE_WRAP_READ,
        action => SEMAPHORE_ACTION_ENTER_READ
    },
    {
        mode   => SEMAPHORE_MODE_ENTER,
        action => SEMAPHORE_ACTION_ENTER
    },
    {
        mode   => SEMAPHORE_MODE_ENTER_READ,
        action => SEMAPHORE_ACTION_ENTER_READ
    },
    {
        mode   => SEMAPHORE_MODE_EXIT_AT_START,
        action => SEMAPHORE_ACTION_EXIT
    },
    {
        mode   => SEMAPHORE_MODE_EXIT_READ_AT_START,
        action => SEMAPHORE_ACTION_EXIT_READ
    }
];

###############################################################################
# Array with semaphore sequence used after entity process.
#
use constant SEMAPHORE_FINISH_SEQUENCE => [
    {
        mode   => SEMAPHORE_MODE_EXIT_READ,
        action => SEMAPHORE_ACTION_EXIT_READ
    },
    {
        mode   => SEMAPHORE_MODE_EXIT,
        action => SEMAPHORE_ACTION_EXIT
    },
    {
        mode   => SEMAPHORE_MODE_WRAP_READ,
        action => SEMAPHORE_ACTION_EXIT_READ
    },
    {
        mode   => SEMAPHORE_MODE_WRAP,
        action => SEMAPHORE_ACTION_EXIT
    }
];

###############################################################################
# Semaphore default client modes used in processing modes.
#
use constant SEMAPHORE_DEFAULT_CLIENT_MODES => {
    SEMAPHORE_MODE_WRAP()               => SEMAPHORE_CLIENT_MODE_ENTITY,
    SEMAPHORE_MODE_WRAP_READ()          => SEMAPHORE_CLIENT_MODE_ENTITY,
    SEMAPHORE_MODE_ENTER()              => SEMAPHORE_CLIENT_MODE_JOBSET,
    SEMAPHORE_MODE_ENTER_READ()         => SEMAPHORE_CLIENT_MODE_JOBSET,
    SEMAPHORE_MODE_EXIT()               => SEMAPHORE_CLIENT_MODE_JOBSET,
    SEMAPHORE_MODE_EXIT_READ()          => SEMAPHORE_CLIENT_MODE_JOBSET,
    SEMAPHORE_MODE_EXIT_AT_START()      => SEMAPHORE_CLIENT_MODE_JOBSET,
    SEMAPHORE_MODE_EXIT_READ_AT_START() => SEMAPHORE_CLIENT_MODE_JOBSET
};

our @EXPORT = qw(
    SEMAPHORE_MODE_WRAP
    SEMAPHORE_MODE_WRAP_READ
    SEMAPHORE_MODE_ENTER
    SEMAPHORE_MODE_ENTER_READ
    SEMAPHORE_MODE_EXIT
    SEMAPHORE_MODE_EXIT_READ
    SEMAPHORE_MODE_EXIT_AT_START
    SEMAPHORE_MODE_EXIT_READ_AT_START
    SEMAPHORE_ACTION_ENTER
    SEMAPHORE_ACTION_ENTER_READ
    SEMAPHORE_ACTION_EXIT
    SEMAPHORE_ACTION_EXIT_READ
    SEMAPHORE_CLIENT_MODE_ENTITY
    SEMAPHORE_CLIENT_MODE_JOBSET
    SEMAPHORE_CLIENT_MODE_SINGLE
    SEMAPHORE_RUN_SEQUENCE
    SEMAPHORE_FINISH_SEQUENCE
    SEMAPHORE_DEFAULT_CLIENT_MODES
);

1;
