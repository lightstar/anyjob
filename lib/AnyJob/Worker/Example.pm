package AnyJob::Worker::Example;

use strict;
use warnings;
use utf8;

use base 'AnyJob::Worker::Base';

sub run {
    my $self = shift;

    sleep(2);

    $self->sendLog("Step 1");

    sleep(5);

    $self->sendLog("Step 2");

    sleep(10);

    $self->sendSuccess("done");
}

1;
