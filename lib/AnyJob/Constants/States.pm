package AnyJob::Constants::States;

use strict;
use warnings;
use utf8;

use base 'Exporter';

use constant STATE_BEGIN => 'begin';
use constant STATE_RUN => 'run';
use constant STATE_FINISHED => 'finished';

our @EXPORT = qw(
    STATE_BEGIN
    STATE_RUN
    STATE_FINISHED
    );

1;
