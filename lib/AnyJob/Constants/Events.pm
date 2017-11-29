package AnyJob::Constants::Events;

use strict;
use warnings;
use utf8;

use base 'Exporter';

use constant EVENT_CREATE => 'create';
use constant EVENT_FINISH => 'finish';
use constant EVENT_PROGRESS => 'progress';
use constant EVENT_REDIRECT => 'redirect';
use constant EVENT_CLEAN => 'clean';
use constant EVENT_CREATE_JOBSET => 'createJobSet';
use constant EVENT_FINISH_JOBSET => 'finishJobSet';
use constant EVENT_PROGRESS_JOBSET => 'progressJobSet';
use constant EVENT_CLEAN_JOBSET => 'cleanJobSet';

use constant EVENT_TYPE_JOB => 'job';
use constant EVENT_TYPE_JOBSET => 'jobset';

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
    EVENT_TYPE_JOB
    EVENT_TYPE_JOBSET
    );

1;
