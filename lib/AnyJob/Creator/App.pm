package AnyJob::Creator::App;

use strict;
use warnings;
use utf8;

use base 'AnyJob::Creator';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{busy} = 0;
    $self->{running} = 1;

    $self->debug('Started');
    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$self->stop()};

    return $self;
}

sub stop {
    my $self = shift;

    $self->debug('Stopping by signal');
    $self->{running} = 0;

    unless ($self->{busy}) {
        $self->shutdown();
    }
}

sub setBusy {
    my $self = shift;
    my $busy = shift;

    unless ($self->{running}) {
        $self->shutdown();
    }

    $self->{busy} = $busy || 0;
}

sub shutdown {
    my $self = shift;
    $self->debug('Stopped');
    exit(0);
}

1;
