package AnyJob::Constants::Defaults;

use strict;
use warnings;
use utf8;

use base 'Exporter';

use constant DEFAULT_LIMIT => 10;
use constant DEFAULT_DELAY => 1;
use constant DEFAULT_CLEAN_TIMEOUT => 3600;

our @EXPORT = qw(
    DEFAULT_LIMIT
    DEFAULT_DELAY
    DEFAULT_CLEAN_TIMEOUT
    );

1;
