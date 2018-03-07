package AnyJob::Worker::Job::Example;

###############################################################################
# Example subclass of 'AnyJob::Worker::Job::Base' which does nothing useful but should help you get started
# with writing your own specific job modules.
# To specify this module as job module use string 'example' (lower-cased part after 'AnyJob::Worker::Job::')
# as value of job configuration parameter 'module'.
#
# Author:       LightStar
# Created:      27.10.2017
# Last update:  05.03.2018
#

use strict;
use warnings;
use utf8;

use base 'AnyJob::Worker::Job::Base';

###############################################################################
# Implementation of main job method which is executed when this job is run.
# It just sends some messages to log with pauses and then successfully finishes job.
#
sub run {
    my $self = shift;

    sleep(2);

    $self->sendLog('Step 1');

    sleep(5);

    $self->sendLog('Step 2');

    sleep(10);

    $self->sendSuccess('done', { text => 'Result' });
}

1;
