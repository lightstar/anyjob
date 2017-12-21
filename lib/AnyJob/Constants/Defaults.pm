package AnyJob::Constants::Defaults;

###############################################################################
# Constants used as some default values.
#
# Author:       LightStar
# Created:      29.11.2017
# Last update:  04.12.2017
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
# Default path for observers configuration (relative to config file).
#
use constant DEFAULT_OBSERVERS_CONFIG_PATH => 'observers';

###############################################################################
# Default path for creators configuration (relative to config file).
#
use constant DEFAULT_CREATORS_CONFIG_PATH => 'creators';

###############################################################################
# Default path for builds configuration (relative to config file).
#
use constant DEFAULT_BUILDS_CONFIG_PATH => 'builds';

###############################################################################
# Default directory for templates.
#
use constant DEFAULT_TEMPLATES_PATH => '{ANYJOB_PATH}/templates/current';

###############################################################################
# Default work dir for worker execution.
#
use constant DEFAULT_WORKER_WORK_DIR => '{ANYJOB_PATH}';

###############################################################################
# Default worker executable.
#
use constant DEFAULT_WORKER_EXEC => '{ANYJOB_PATH}/bin/anyjobw.pl';

###############################################################################
# Default prefix for specific job modules.
#
use constant DEFAULT_WORKER_PREFIX => 'AnyJob::Worker';

###############################################################################
# Default method in specific job module to run.
#
use constant DEFAULT_WORKER_METHOD => 'run';

###############################################################################
# Default list of creator internal properties.
#
use constant DEFAULT_INTERNAL_PROPS => 'observer,response_url';

###############################################################################
# Default slack api url.
#
use constant DEFAULT_SLACK_API => 'https://slack.com/api/';

our @EXPORT = qw(
    DEFAULT_LIMIT
    DEFAULT_DELAY
    DEFAULT_CLEAN_TIMEOUT
    DEFAULT_CLEAN_DELAY
    DEFAULT_PIDFILE
    DEFAULT_ANYJOB_PATH
    DEFAULT_CONFIG_FILE
    DEFAULT_REDIS
    DEFAULT_NODES_CONFIG_PATH
    DEFAULT_JOBS_CONFIG_PATH
    DEFAULT_OBSERVERS_CONFIG_PATH
    DEFAULT_CREATORS_CONFIG_PATH
    DEFAULT_BUILDS_CONFIG_PATH
    DEFAULT_TEMPLATES_PATH
    DEFAULT_WORKER_WORK_DIR
    DEFAULT_WORKER_EXEC
    DEFAULT_WORKER_PREFIX
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
