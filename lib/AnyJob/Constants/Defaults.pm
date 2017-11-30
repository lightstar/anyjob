package AnyJob::Constants::Defaults;

use strict;
use warnings;
use utf8;

use base 'Exporter';

use constant DEFAULT_LIMIT => 10;
use constant DEFAULT_DELAY => 1;
use constant DEFAULT_CLEAN_TIMEOUT => 3600;
use constant DEFAULT_CLEAN_DELAY => 60;
use constant DEFAULT_UPDATE_COUNTS_DELAY => 30;
use constant DEFAULT_PIDFILE => '/var/run/anyjobd.pid';

our @EXPORT = qw(
    DEFAULT_LIMIT
    DEFAULT_DELAY
    DEFAULT_CLEAN_TIMEOUT
    DEFAULT_CLEAN_DELAY
    DEFAULT_UPDATE_COUNTS_DELAY
    DEFAULT_PIDFILE
    );

1;
