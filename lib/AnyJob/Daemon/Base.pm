package AnyJob::Daemon::Base;

use strict;
use warnings;
use utf8;

use POSIX qw(setsid dup2 :sys_wait_h);
use Time::HiRes qw(usleep);
use File::Basename;
use IO::File;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{process}) {
        require Carp;
        Carp::confess('No process function');
    }

    unless ($self->{logger}) {
        require Carp;
        Carp::confess('No logger');
    }

    $self->{detached} ||= 0;
    $self->{pidfile} ||= '/var/run/daemon.pid';
    $self->{delay} ||= 1;
    $self->{delay} = int($self->{delay} * 1000000);
    $self->{script} = basename($0);

    unless ($self->canRun()) {
        require Carp;
        Carp::confess('Couldn\'t run, some other instance is running');
    }

    return $self;
}

sub daemonize {
    my $self = shift;

    my $pid = fork();
    if ($pid != 0) {
        exit(0);
    }

    unless (defined($pid)) {
        $self->error('Can\'t fork: ' . $!);
        exit(1);
    }

    unless (setsid()) {
        $self->error('Can\'t start a new session: ' . $!);
        exit(1);
    }

    my $maxFh;
    unless (open($maxFh, '>', '/dev/null')) {
        $self->error('Can\'t open /dev/null: ' . $!);
        exit(1);
    }
    if (fileno($maxFh) != 1) {
        dup2(fileno($maxFh), 1);
    }
    if (fileno($maxFh) != 2) {
        dup2(fileno($maxFh), 2);
    }
    if (fileno($maxFh) > 2) {
        close($maxFh);
    }
}

sub run {
    my $self = shift;

    unless ($self->{detached}) {
        $self->daemonize();
    }

    unless ($self->writePid()) {
        $self->error('Can\'t write pid');
        exit(1);
    }

    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$self->stop()};

    $self->debug('Started');

    $self->{running} = 1;
    while ($self->{running}) {
        eval {
            $self->{process}->();
        };

        if ($@) {
            $self->error('Process error: ' . $@);
        }

        usleep($self->{delay}) if $self->{running} and $self->{delay};
    }

    $self->debug('Stopped');

    unless ($self->deletePid()) {
        $self->error('Can\'t delete pid file');
    }

    delete $self->{process};
}

sub stop {
    my $self = shift;
    $self->debug('Stopping by signal');
    $self->{running} = 0;
}

sub debug {
    my $self = shift;
    my $message = shift;
    $self->{logger}->debug($message);
}

sub error {
    my $self = shift;
    my $message = shift;
    $self->{logger}->error($message);
}

sub readPid {
    my $self = shift;
    return (-s $self->{pidfile}) ? readInt($self->{pidfile}) : 0;
}

sub writePid {
    my $self = shift;
    writeInt($self->{pidfile}, $$) or return undef;
    chmod(0666, $self->{pidfile}) or return undef;
    return 1;
}

sub deletePid {
    my $self = shift;
    if (-e $self->{pidfile}) {
        unlink($self->{pidfile}) or return undef;
    }
    return 1;
}

sub canRun {
    my $self = shift;
    if (my $pid = $self->readPid()) {
        return isProcRun($pid, $self->{script}) ? 0 : 1;
    }
    return 1;
}

sub readInt {
    my $fileName = shift;

    my $fh = IO::File->new($fileName, 'r');
    return 0 unless $fh;
    my $value = int(<$fh>);
    $fh->close();

    return $value;
}

sub writeInt {
    my $fileName = shift;
    my $value = shift;

    my $fh = IO::File->new($fileName, 'w');
    return undef unless $fh;
    print $fh $value;
    close($fh);

    return 1;
}

sub isProcRun {
    my $pid = shift;
    my $fileName = shift;

    return undef unless $pid;

    my $procFile = '/proc/' . $pid . '/cmdline';
    return undef unless -e $procFile;
    return 1 unless $fileName;

    my $fh = IO::File->new($procFile, 'r');
    return undef unless $fh;

    my $str = <$fh>;
    close($fh);
    return undef unless $str;

    return 1 if $str =~ /$fileName/;

    return undef;
}

1;
