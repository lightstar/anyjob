package AnyJob::Creator::Observer;

###############################################################################
# Class used to observe events targeted to specified private observers. All received events are then sent to provided
# creator addons which should implement 'receivePrivateEvent' method. Observing is done inside asynchronous AnyEvent
# environment.
#
# Author:       LightStar
# Created:      16.02.2018
# Last update:  13.12.2018
#

use strict;
use warnings;
use utf8;

use Scalar::Util qw(weaken);
use JSON::XS;
use AnyEvent::RipeRedis;

use AnyJob::Constants::Defaults qw(DEFAULT_REDIS);

###############################################################################
# Construct new AnyJob::Creator::Observer object.
#
# Arguments:
#     parent        - parent component which is usually AnyJob::Creator object.
#     names         - array of strings with private observer names. Names are arbitrary strings uniquely
#                     identifying target for that events (it could be addon names, user names or anything that is
#                     meaningfull for target creator addon).
#     addonsByNames - hash where keys are private observer names and values are creator addon objects which will
#                     receive events targeted to corresponding observers.
# Returns:
#     AnyJob::Creator::Observer object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{parent})) {
        require Carp;
        Carp::confess('No parent provided');
    }

    unless (defined($self->{names})) {
        require Carp;
        Carp::confess('No names provided');
    }

    unless (defined($self->{addonsByNames})) {
        require Carp;
        Carp::confess('No addons by names provided');
    }

    $self->{queues} = [ map {'anyjob:observerq:private:' . $_} @{$self->{names}} ];
    $self->{addonsByQueues} = { map {'anyjob:observerq:private:' . $_ => $self->{addonsByNames}->{$_}}
        keys(%{$self->{addonsByNames}}) };

    my $redisServer = $self->config->redis || DEFAULT_REDIS;
    my ($redisHost, $redisPort) = split(':', $redisServer);

    $self->{redis} = AnyEvent::RipeRedis->new(
        host     => $redisHost,
        port     => $redisPort,
        on_error => sub {}
    );

    return $self;
}

###############################################################################
# Returns:
#     parent component which is usually AnyJob::Creator object.
#
sub parent {
    my $self = shift;
    return $self->{parent};
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{parent}->config;
}

###############################################################################
# Write debug message to log.
#
# Arguments:
#     message - string debug message.
#
sub debug {
    my $self = shift;
    my $message = shift;
    $self->{parent}->debug($message);
}

###############################################################################
# Write error message to log.
#
# Arguments:
#     message - string error message.
#
sub error {
    my $self = shift;
    my $message = shift;
    $self->{parent}->error($message);
}

###############################################################################
# Start observing private events.
#
sub observe {
    my $self = shift;

    weaken($self);
    $self->{redis}->blpop(@{$self->{queues}}, 0, sub {
        my $reply = shift;
        my $error = shift;

        if (defined($error) or not defined($self)) {
            return;
        }

        my ($queue, $event) = @$reply;
        if (defined($queue) and defined($event)) {
            utf8::encode($event);
            eval {
                $event = decode_json($event);
            };
            if ($@) {
                $self->error('Can\'t decode event: ' . $event);
            } else {
                if (exists($event->{props}->{service})) {
                    $self->{addonsByQueues}->{$queue}->receiveServiceEvent($event);
                } else {
                    $self->{addonsByQueues}->{$queue}->receivePrivateEvent($event);
                }
            }
        }
        $self->observe();
    });
}

###############################################################################
# Stop observing private events.
#
sub stop {
    my $self = shift;
    $self->{redis}->disconnect();
}

1;
