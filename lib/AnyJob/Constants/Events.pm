package AnyJob::Constants::Events;

###############################################################################
# Constants used as event names and types.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  27.11.2018
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
# Event sent when information about delayed works is requested.
#
use constant EVENT_DELAYED_WORKS => 'delayedWorks';

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
    EVENT_DELAYED_WORKS
    EVENT_TYPE_JOB
    EVENT_TYPE_JOBSET
    EVENT_TYPE_DELAYED_WORK
);

1;
