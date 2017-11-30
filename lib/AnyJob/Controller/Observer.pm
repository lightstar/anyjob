package AnyJob::Controller::Observer;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(DEFAULT_LIMIT DEFAULT_CLEAN_TIMEOUT);
use AnyJob::DateTime qw(formatDateTime);
use AnyJob::EventFilter;

use base 'AnyJob::Controller::Base';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    unless (defined($self->{name}) and $self->{name} ne '') {
        require Carp;
        Carp::confess('No name provided');
    }

    my $config = $self->getObserverConfig() || {};
    $self->{eventFilter} = AnyJob::EventFilter->new(filter => $config->{event_filter});

    return $self;
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub getObserverConfig {
    my $self = shift;
    return $self->config->getObserverConfig($self->name);
}

sub process {
    my $self = shift;

    my $observerConfig = $self->getObserverConfig() || {};

    if ($self->isProcessDelayed($observerConfig->{delay} || $self->config->observe_delay)) {
        return;
    }

    my $limit = $observerConfig->{limit} || $self->config->limit || DEFAULT_LIMIT;
    my $count = 0;

    while (my $event = $self->redis->lpop('anyjob:observerq:' . $self->name)) {
        eval {
            $event = decode_json($event);
        };
        if ($@) {
            $self->error('Can\'t decode event: ' . $event);
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
    Carp::confess('Need to be implemented in descendant');
}

sub preprocessEvent {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    if ($self->checkEventProp($event, 'silent')) {
        return 0;
    }

    unless ($self->eventFilter($event)) {
        return 0;
    }

    $event->{config} = $config;
    if (exists($event->{type})) {
        $event->{job} = $self->config->getJobConfig($event->{type}) || {};
    }

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

    my $observerConfig = $self->getObserverConfig() || {};
    my $clean_timeout = $event->{props}->{log_clean_timeout} || $observerConfig->{log_clean_timeout} ||
        $self->config->clean_timeout || DEFAULT_CLEAN_TIMEOUT;

    $self->redis->zadd('anyjob:observer:' . $self->name . ':log', time() + $clean_timeout, $event->{id});
    $self->redis->rpush('anyjob:observer:' . $self->name . ':log:' . $event->{id},
        encode_json($event->{progress}->{log}));
}

sub collectLogs {
    my $self = shift;
    my $event = shift;

    unless (exists($event->{id})) {
        return [];
    }

    my @logs = $self->redis->lrange('anyjob:observer:' . $self->name . ':log:' . $event->{id}, '0', '-1');
    foreach my $log (@logs) {
        eval {
            $log = decode_json($log);
        };
        if ($@) {
            $self->error('Can\'t decode log: ' . $log);
            return [];
        }

        if (exists($log->{time})) {
            $log->{time} = formatDateTime($log->{time});
        }
    }

    $self->cleanLog($event->{id});

    return \@logs;
}

sub cleanLogs {
    my $self = shift;

    my $observerConfig = $self->getObserverConfig() || {};
    my $limit = $observerConfig->{log_clean_limit} || $self->config->limit || DEFAULT_LIMIT;

    my %ids = $self->redis->zrangebyscore('anyjob:observer:' . $self->name . ':log', '-inf', time(),
        'WITHSCORES', 'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanLog($id);
    }
}

sub cleanLog {
    my $self = shift;
    my $id = shift;

    $self->debug('Clean logs in observer \'' . $self->name . '\' for job \'' . $id . '\'');

    $self->redis->zrem('anyjob:observer:' . $self->name . ':log', $id);
    $self->redis->del('anyjob:observer:' . $self->name . ':log:' . $id);
}

sub eventFilter {
    my $self = shift;
    my $event = shift;
    return $self->{eventFilter}->filter($event);
}

sub filterEvents {
    my $self = shift;
    my $events = shift;
    return [ grep {$self->{eventFilter}->filter($_)} @$events ];
}

1;
