package AnyJob::Controller::Global::Progress;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;

    while (my $progress = $self->redis->lpop("anyjob:progress_queue")) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error("Can't decode progress: " . $progress);
        } else {
            $self->debug("Got jobset progress: " . encode_json($progress));
        }

        $count++;
        last if $count >= $limit;
    }
}

1;
