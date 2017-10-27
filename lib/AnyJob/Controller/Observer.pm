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

    while (my $event = $self->redis->lpop("anyjob:observerq:" . $self->name)) {
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

    $self->redis->zadd("anyjob:observer:" . $self->name . ":log", time(), $event->{id});
    $self->redis->rpush("anyjob:observer:" . $self->name . ":log:" . $event->{id},
        encode_json($event->{progress}->{log}));
}

sub collectLogs {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id})) {
        return [];
    }

    my $time = $self->redis->zscore("anyjob:observer:" . $self->name . ":log", $event->{id});
    unless ($time) {
        return [];
    }

    my @logs = $self->redis->lrange("anyjob:observer:" . $self->name . ":log:" . $event->{id}, "0", "-1");
    foreach my $log (@logs) {
        eval {
            $log = decode_json($log);
        };
        if ($@) {
            $self->error("Can't decode log: " . $log);
            return [];
        }

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

    my %ids = $self->redis->zrangebyscore("anyjob:observer:" . $self->name . ":log", "-inf",
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

    $self->redis->zrem("anyjob:observer:" . $self->name . ":log", $id);
    $self->redis->del("anyjob:observer:" . $self->name . ":log:" . $id);
}

1;
