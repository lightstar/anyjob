package AnyJob::Creator::App;

###############################################################################
# Version of creator component designed to use inside dancer2 web application.
# Its main purpose is to catch interruption signals and shutdown application only when it is safe to do it.
# Also it launches observing private events for all known addons running inside web app.
#
# Author:       LightStar
# Created:      30.10.2017
# Last update:  12.03.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Creator::Observer;

use base 'AnyJob::Creator';

###############################################################################
# Names of all creator addons running inside dancer2 web application.
#
use constant ADDONS => [ 'web', 'slack' ];

###############################################################################
# Construct new AnyJob::Creator::App object.
#
# Returns:
#     AnyJob::Creator:App object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{busy} = 0;
    $self->{running} = 1;

    $self->debug('Started');
    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$self->stop()};

    my $addonsByNames = {};
    foreach my $name (@{ADDONS()}) {
        $addonsByNames->{$name} = $self->addon($name);
    }

    $self->{observer} = AnyJob::Creator::Observer->new(
        parent        => $self,
        names         => [ keys(%{$addonsByNames}) ],
        addonsByNames => $addonsByNames
    );
    $self->{observer}->observe();

    return $self;
}

###############################################################################
# Set stop flag so application will shutdown when it is safe.
# Shutdown immediately if it is safe right now.
#
sub stop {
    my $self = shift;

    if ($self->{running}) {
        $self->debug('Stopping now');
        $self->{running} = 0;

        unless ($self->{busy}) {
            $self->shutdown();
        }
    }
}

###############################################################################
# Set or unset 'busy' flag. When 'busy' flag is unset, it is safe to shutdown.
# Shutdown right here if interruption signal was catched previously.
#
# Arguments:
#     busy - 0/1 value for the 'busy' flag.
#
sub setBusy {
    my $self = shift;
    my $busy = shift;

    unless ($self->{running}) {
        $self->shutdown();
    }

    $self->{busy} = $busy || 0;
}

###############################################################################
# Perform shutdown.
#
sub shutdown {
    my $self = shift;

    foreach my $name (@{ADDONS()}) {
        $self->addon($name)->stop();
    }
    $self->{observer}->stop();

    $self->debug('Stopped');

    exit(0);
}

1;
