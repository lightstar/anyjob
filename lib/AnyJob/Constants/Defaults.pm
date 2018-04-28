package AnyJob::Constants::Defaults;

###############################################################################
# Constants used as some default values.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  28.04.2018
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Default minimum delay in seconds between daemon loop processing.
#
use constant DEFAULT_MIN_DELAY => 1;

###############################################################################
# Default maximum delay in seconds between daemon loop processing.
#
use constant DEFAULT_MAX_DELAY => 1;

###############################################################################
# Default limit of cleaned timeouted objects in one iteration.
#
use constant DEFAULT_CLEAN_LIMIT => 10;

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
use constant DEFAULT_DAEMON_PIDFILE => '/var/run/anyjobd.pid';

###############################################################################
# Default delay in seconds between tries to stop all child processes.
#
use constant DEFAULT_CHILD_STOP_DELAY => 1;

###############################################################################
# Default maximum number of tries to stop all child processes.
#
use constant DEFAULT_CHILD_STOP_TRIES => 10;

###############################################################################
# Default delay in seconds between tries to stop all worker daemon processes.
#
use constant DEFAULT_WORKER_STOP_DELAY => 1;

###############################################################################
# Default delay in seconds between checks that worker daemons are running.
#
use constant DEFAULT_WORKER_CHECK_DELAY => 10;

###############################################################################
# Default worker max run time in seconds.
#
use constant DEFAULT_WORKER_MAX_RUN_TIME => 86400;

###############################################################################
# Default maximum number of tries to stop all worker daemon processes.
#
use constant DEFAULT_WORKER_STOP_TRIES => 10;

###############################################################################
# Default anyjob installation path.
#
use constant DEFAULT_ANYJOB_PATH => '/opt/anyjob';

###############################################################################
# Default config file.
#
use constant DEFAULT_CONFIG_FILE => '{ANYJOB_PATH}/etc/current/anyjob.cfg';

###############################################################################
# Default redis address and port.
#
use constant DEFAULT_REDIS => '127.0.0.1:6379';

###############################################################################
# Default path for nodes configuration (relative to config file).
#
use constant DEFAULT_NODES_CONFIG_PATH => 'nodes';

###############################################################################
# Default path for jobs configuration (relative to config file).
#
use constant DEFAULT_JOBS_CONFIG_PATH => 'jobs';

###############################################################################
# Default path for jobsets configuration (relative to config file).
#
use constant DEFAULT_JOBSETS_CONFIG_PATH => 'jobsets';

###############################################################################
# Default path for observers configuration (relative to config file).
#
use constant DEFAULT_OBSERVERS_CONFIG_PATH => 'observers';

###############################################################################
# Default path for creators configuration (relative to config file).
#
use constant DEFAULT_CREATORS_CONFIG_PATH => 'creators';

###############################################################################
# Default path for builders configuration (relative to config file).
#
use constant DEFAULT_BUILDERS_CONFIG_PATH => 'builders';

###############################################################################
# Default path for semaphores configuration (relative to config file).
#
use constant DEFAULT_SEMAPHORES_CONFIG_PATH => 'semaphores';

###############################################################################
# Default path for workers configuration (relative to config file).
#
use constant DEFAULT_WORKERS_CONFIG_PATH => 'workers';

###############################################################################
# Default directory for templates.
#
use constant DEFAULT_TEMPLATES_PATH => '{ANYJOB_PATH}/templates/current';

###############################################################################
# Default worker daemon executable.
#
use constant DEFAULT_WORKER_DAEMON_EXEC => '{ANYJOB_PATH}/bin/anyjobwd.pl';

###############################################################################
# Default worker executable.
#
use constant DEFAULT_WORKER_EXEC => '{ANYJOB_PATH}/bin/anyjobw.pl';

###############################################################################
# Default pid file for worker daemon. Substring '{name}' here must be substituted for worker name.
#
use constant DEFAULT_WORKER_PIDFILE => '/var/run/anyjobwd-{name}.pid';

###############################################################################
# Default work dir for worker execution.
#
use constant DEFAULT_WORKER_WORK_DIR => '{ANYJOB_PATH}';

###############################################################################
# Default prefix for worker context modules.
#
use constant DEFAULT_WORKER_CONTEXT_PREFIX => 'AnyJob::Worker::Context';

###############################################################################
# Default prefix for specific job modules.
#
use constant DEFAULT_WORKER_PREFIX => 'AnyJob::Worker::Job';

###############################################################################
# Default method in specific job module to run.
#
use constant DEFAULT_WORKER_METHOD => 'run';

###############################################################################
# Default list of creator internal properties.
#
use constant DEFAULT_INTERNAL_PROPS => 'creator,author,observer,response_url';

###############################################################################
# Default slack api url.
#
use constant DEFAULT_SLACK_API => 'https://slack.com/api/';

our @EXPORT = qw(
    DEFAULT_MIN_DELAY
    DEFAULT_MAX_DELAY
    DEFAULT_CLEAN_LIMIT
    DEFAULT_CLEAN_TIMEOUT
    DEFAULT_CLEAN_DELAY
    DEFAULT_DAEMON_PIDFILE
    DEFAULT_CHILD_STOP_DELAY
    DEFAULT_CHILD_STOP_TRIES
    DEFAULT_WORKER_STOP_DELAY
    DEFAULT_WORKER_STOP_TRIES
    DEFAULT_WORKER_CHECK_DELAY
    DEFAULT_WORKER_MAX_RUN_TIME
    DEFAULT_ANYJOB_PATH
    DEFAULT_CONFIG_FILE
    DEFAULT_REDIS
    DEFAULT_NODES_CONFIG_PATH
    DEFAULT_JOBS_CONFIG_PATH
    DEFAULT_JOBSETS_CONFIG_PATH
    DEFAULT_OBSERVERS_CONFIG_PATH
    DEFAULT_CREATORS_CONFIG_PATH
    DEFAULT_BUILDERS_CONFIG_PATH
    DEFAULT_WORKERS_CONFIG_PATH
    DEFAULT_SEMAPHORES_CONFIG_PATH
    DEFAULT_TEMPLATES_PATH
    DEFAULT_WORKER_DAEMON_EXEC
    DEFAULT_WORKER_EXEC
    DEFAULT_WORKER_PIDFILE
    DEFAULT_WORKER_WORK_DIR
    DEFAULT_WORKER_PREFIX
    DEFAULT_WORKER_CONTEXT_PREFIX
    DEFAULT_WORKER_METHOD
    DEFAULT_INTERNAL_PROPS
    DEFAULT_SLACK_API
    injectPathIntoConstant
    );

sub injectPathIntoConstant {
    my $value = shift;

    my $anyjobPath = $ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH;
    $value =~ s/\{ANYJOB_PATH\}/$anyjobPath/;

    return $value;
}

1;
