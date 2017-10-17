package AnyJob::Daemon;

use strict;
use warnings;
use utf8;

use POSIX qw(setsid dup2 :sys_wait_h);
use Sys::Syslog qw(syslog);
use Time::HiRes qw(usleep);
use File::Basename;
use IO::File;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless ($self->{config}) {
        require Carp;
        Carp::confess("No config provided");
    }

    unless ($self->{process}) {
        require Carp;
        Carp::confess("No process function");
    }

    $self->{pidfile} = $self->config->daemon->{pidfile} || "/var/run/daemon.pid";
    $self->{delay} = $self->config->daemon->{delay} || 10000000;
    $self->{script} = basename($0);

    unless ($self->canRun()) {
        require Carp;
        Carp::confess("Couldn't run, some other instance is running");
    }

    return $self;
}

sub config {
    my $self = shift;
    return $self->{config};
}

sub daemonize {
    my $self = shift;

    my $pid = fork();
    if ($pid != 0) {
        exit(0);
    }

    unless (defined($pid)) {
        $self->error("Couldn't fork: $!");
        exit(255);
    }

    unless (setsid()) {
        $self->error("Can't start a new session: $!");
        exit(255);
    }

    my $maxFh;
    unless (open($maxFh, ">", "/dev/null")) {
        $self->error("can't open /dev/null: $!");
        exit(255);
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

    unless ($self->writePid()) {
        $self->error("Can't write pid");
        exit(255);
    }
}

sub run {
    my $self = shift;

    $self->daemonize();

    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$self->stop()};

    $self->debug("Started");

    $self->{running} = 1;
    while ($self->{running}) {
        eval {
            $self->{process}->();
        };

        if ($@) {
            $self->error("Process error: $@");
        }

        usleep($self->{delay}) if $self->{running} and $self->{delay};
    }

    $self->debug("Stopped");

    unless ($self->deletePid()) {
        $self->error("Can't delete pid file");
    }

    delete $self->{process};
}

sub stop {
    my $self = shift;
    $self->debug("Stopping by signal");
    $self->{running} = 0;
}

sub debug {
    my ($self, $message) = @_;
    syslog("info", $message);
}

sub error {
    my ($self, $message) = @_;
    syslog("err", $message);
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
    my $filename = shift;

    my $fh = IO::File->new($filename, "r");
    return 0 unless $fh;
    my $value = int(<$fh>);
    $fh->close();

    return $value;
}

sub writeInt {
    my ($filename, $value) = @_;

    my $fh = IO::File->new($filename, "w");
    return undef unless $fh;
    print $fh $value;
    close($fh);

    return 1;
}

sub isProcRun {
    my ($pid, $filename) = @_;

    return undef unless $pid;

    my $procfile = "/proc/$pid/cmdline";
    return undef unless -e $procfile;
    return 1 unless $filename;

    my $fh = IO::File->new($procfile, "r");
    return undef unless $fh;

    my $str = <$fh>;
    close($fh);
    return undef unless $str;

    return 1 if $str =~ /$filename/;

    return undef;
}

1;
