package AnyJob::Controller::Observer;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Base';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    unless ($self->{name}) {
        require Carp;
        Carp::confess("No name provided");
    }

    return $self;
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub observerConfig {
    my $self = shift;
    return $self->config->getObserverConfig($self->name);
}

sub process {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $count = 0;

    while (my $event = $self->redis->lpop("anyjob:observer_queue:" . $self->name)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error("Can't decode event: " . $event);
        } else {
            $self->processEvent($event);
        }

        $count++;
        last if $count >= $limit;
    }

    $self->cleanLogs();
}

sub processEvent {
    my $self = shift;
    my $event = shift;

    require Carp;
    Carp::confess("Need to be implemented in descendant");
}

sub checkEventProp {
    my $self = shift;
    my $event = shift;
    my $prop = shift;

    if (exists($event->{props}) and $event->{props}->{$prop}) {
        return 1;
    }

    if (exists($event->{type})) {
        my $jobConfig = $self->config->getJobConfig($event->{type});
        if ($jobConfig and $jobConfig->{$prop}) {
            return 1;
        }
    }

    return 0;
}

sub preprocessEvent {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    if ($self->checkEventProp($event, "silent")) {
        return 0;
    }

    $event->{config} = $config;

    if ($event->{time}) {
        $event->{time} = formatDateTime($event->{time});
    }

    return 1;
}

sub saveLog {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id}) and exists($event->{progress}) and exists($event->{progress}->{log})) {
        return;
    }

    $self->redis->zadd("anyevent:observer_data:" . $self->name . ":log", time(), $event->{id});
    $self->redis->rpush("anyevent:observer_data:" . $self->name . ":log:" . $event->{id},
        encode_json($event->{progress}->{log}));
}

sub collectLogs {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id})) {
        return [];
    }

    my $time = $self->redis->zscore("anyjob:observer_data:" . $self->name . ":log", $event->{id});
    unless ($time) {
        return [];
    }

    my @logs = $self->redis->lrange("anyevent:observer_data:" . $self->name . ":log:" . $event->{id});
    foreach my $log (@logs) {
        if (exists($log->{time})) {
            $log->{time} = formatDateTime($log->{time});
        }
    }

    $self->cleanLog($event->{id}, $time);

    return \@logs;
}

sub cleanLogs {
    my $self = shift;

    my $limit = $self->config->limit || 10;
    my $cleanBefore = $self->config->clean_before || 3600;

    my %ids = $self->redis->zrangebyscore("anyjob:observer_data:" . $self->name . ":log", "-inf",
        time() - $cleanBefore, "WITHSCORES", "LIMIT", 0, $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanLog($id, $ids{$id});
    }
}

sub cleanLog {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    $self->debug("Clean logs in observer '" . $self->name . "' for job '" . $id . "' last updated at " .
        formatDateTime($time));

    $self->redis->zrem("anyjob:observer_data:" . $self->name . ":log", $id);
    $self->redis->del("anyevent:observer_data:" . $self->name . ":log:" . $id);
}

1;
