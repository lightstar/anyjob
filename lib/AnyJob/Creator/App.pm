package AnyJob::Creator::App;

use strict;
use warnings;
use utf8;

use base 'AnyJob::Creator';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{isBusy} = 0;
    $self->{isShutdown} = 0;

    $self->debug('Started');

    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {
        $self->{isShutdown} = 1;
        $self->shutdownIfNotBusy();
    };

    return $self;
}

sub setBusy {
    my $self = shift;
    my $isBusy = shift;

    if ($self->{isShutdown}) {
        $self->shutdown();
    }

    $self->{isBusy} = $isBusy;
}

sub shutdownIfNotBusy {
    my $self = shift;

    unless ($self->{isBusy}) {
        $self->shutdown();
    }
}

sub shutdown {
    my $self = shift;
    $self->debug('Stopped');
    exit(0);
}

1;
