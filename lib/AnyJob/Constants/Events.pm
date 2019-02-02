package AnyJob::Constants::Events;

###############################################################################
# Constants used as event names and types.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  02.02.2019
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Event sent when job is created.
#
use constant EVENT_CREATE => 'create';

###############################################################################
# Event sent when job is finished.
#
use constant EVENT_FINISH => 'finish';

###############################################################################
# Event sent when job somehow progresses.
#
use constant EVENT_PROGRESS => 'progress';

###############################################################################
# Event sent when job is redirected to another node.
#
use constant EVENT_REDIRECT => 'redirect';

###############################################################################
# Event sent when job is cleaned by timeout.
#
use constant EVENT_CLEAN => 'clean';

###############################################################################
# Event sent when jobset is created.
#
use constant EVENT_CREATE_JOBSET => 'createJobSet';

###############################################################################
# Event sent when jobset is finished.
#
use constant EVENT_FINISH_JOBSET => 'finishJobSet';

###############################################################################
# Event sent when jobset somehow progresses.
#
use constant EVENT_PROGRESS_JOBSET => 'progressJobSet';

###############################################################################
# Event sent when jobset is cleaned by timeout.
#
use constant EVENT_CLEAN_JOBSET => 'cleanJobSet';

###############################################################################
# Event sent when delayed work is created.
#
use constant EVENT_CREATE_DELAYED_WORK => 'createDelayedWork';

###############################################################################
# Event sent when delayed work is updated.
#
use constant EVENT_UPDATE_DELAYED_WORK => 'updateDelayedWork';

###############################################################################
# Event sent when delayed work is deleted.
#
use constant EVENT_DELETE_DELAYED_WORK => 'deleteDelayedWork';

###############################################################################
# Event sent when delayed work is processed.
#
use constant EVENT_PROCESS_DELAYED_WORK => 'processDelayedWork';

###############################################################################
# Event sent when delayed work is skipped.
#
use constant EVENT_SKIP_DELAYED_WORK => 'skipDelayedWork';

###############################################################################
# Event sent when information about delayed works is requested.
#
use constant EVENT_GET_DELAYED_WORKS => 'getDelayedWorks';

###############################################################################
# Event sent as status reply after some operation with success or error message.
#
use constant EVENT_STATUS => 'status';

###############################################################################
# Event type for events related to job.
#
use constant EVENT_TYPE_JOB => 'job';

###############################################################################
# Event type for events related to jobset.
#
use constant EVENT_TYPE_JOBSET => 'jobset';

###############################################################################
# Event type for events related to delayed works.
#
use constant EVENT_TYPE_DELAYED_WORK => 'delayedWork';

###############################################################################
# Event type for events related to statuses.
#
use constant EVENT_TYPE_STATUS => 'status';

our @EXPORT = qw(
    EVENT_CREATE
    EVENT_FINISH
    EVENT_PROGRESS
    EVENT_REDIRECT
    EVENT_CLEAN
    EVENT_CREATE_JOBSET
    EVENT_FINISH_JOBSET
    EVENT_PROGRESS_JOBSET
    EVENT_CLEAN_JOBSET
    EVENT_CREATE_DELAYED_WORK
    EVENT_UPDATE_DELAYED_WORK
    EVENT_DELETE_DELAYED_WORK
    EVENT_PROCESS_DELAYED_WORK
    EVENT_SKIP_DELAYED_WORK
    EVENT_GET_DELAYED_WORKS
    EVENT_STATUS
    EVENT_TYPE_JOB
    EVENT_TYPE_JOBSET
    EVENT_TYPE_DELAYED_WORK
    EVENT_TYPE_STATUS
);

1;
