package AnyJob::States;

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    $STATE_BEGIN
    $STATE_RUN
    $STATE_FINISHED
    );

our $STATE_BEGIN = 'begin';
our $STATE_RUN = 'run';
our $STATE_FINISHED = 'finished';

1;
