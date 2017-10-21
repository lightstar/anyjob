package AnyJob::Controller::Node::Progress;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Controller::Node';

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;

    while (my $progress = $self->redis->lpop("anyjob:progress_queue:" . $self->node)) {
        eval {
            $progress = decode_json($progress);
        };
        if ($@) {
            $self->error("Can't decode progress: " . $progress);
        } elsif (exists($progress->{success})) {
            $self->finishJob($progress);
        } else {
            $self->progressJob($progress);
        }

        $count++;
        last if $count >= $limit;
    }
}

sub progressJob {
    my $self = shift;
    my $progress = shift;

    my $id = delete $progress->{id};

    my $job = $self->getJob($id);
    unless ($job) {
        return;
    }

    $self->debug("Progress of job '" . $id . "': " . encode_json($progress));

    if ($progress->{state}) {
        $job->{state} = $progress->{state};
        $self->redis->set("anyjob:job:" . $id, encode_json($job));
    }

    if ($progress->{log}) {
        $self->redis->rpush("anyjob:job:" . $id . ":log", encode_json($progress->{log}));
    }

    $self->sendEvent("progress", {
            id       => $id,
            type     => $job->{type},
            params   => $job->{params},
            progress => $progress
        });
}

sub finishJob {
    my $self = shift;
    my $progress = shift;

    my $id = $progress->{id};

    my $job = $self->getJob($id);
    unless ($job) {
        return;
    }

    $self->sendEvent("finish", {
            id      => $id,
            type    => $job->{type},
            params  => $job->{params},
            success => $progress->{success},
            message => $progress->{message}
        });

    $self->debug("Job '" . $id . "' " . ($progress->{success} ? "successfully finished" : "finished with error") .
        ": '" . $progress->{message} . "'");

    if (my $time = $self->redis->zscore("anyjob:job", $id)) {
        $self->cleanJob($id, $time);
    }
}

1;
