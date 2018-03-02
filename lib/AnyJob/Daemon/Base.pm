package AnyJob::Daemon::Base;

###############################################################################
# Class for daemon object which actually can be used for some other daemon, not necessarily anyjob-related.
#
# Author:       LightStar
# Created:      19.10.2017
# Last update:  02.03.2018
#

use strict;
use warnings;
use utf8;

use POSIX qw(setsid dup2 :sys_wait_h);
use Time::HiRes qw(usleep);
use File::Basename;
use Scalar::Util qw(looks_like_number);

###############################################################################
# Construct new AnyJob::Daemon::Base object.
#
# Arguments:
#     processor      - object which must implement 'process' method. It will be called in daemon process loop.
#     logger         - logger object which must implement 'debug' and 'error' methods.
#     detached       - 0/1 flag. If set daemon will run in 'detached' mode i.e. will fork, close all input/output, etc.
#     delay          - delay in seconds between process loop iterations. By default - 0 (i.e. no delay).
#     pidfile        - file name to store daemon process pid value. By default - '/var/run/daemon.pid'.
#     childStopDelay - delay in seconds between tries to stop all childs in the end of all processing. By default - 1.
#     childStopTries - maximum number of tries to stop all childs in the end of all processing. By default - 10.
# Returns:
#     AnyJob::Daemon::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{processor}) and $self->{processor}->can('process')) {
        require Carp;
        Carp::confess('No processor object');
    }

    unless (defined($self->{logger}) and $self->{logger}->can('debug') and $self->{logger}->can('error')) {
        require Carp;
        Carp::confess('No logger');
    }

    $self->{detached} ||= 0;
    $self->{pidfile} ||= '/var/run/daemon.pid';
    $self->{delay} ||= 0;
    $self->{delay} = int($self->{delay} * 1000000);
    $self->{script} = basename($0);
    $self->{childStopDelay} ||= 1;
    $self->{childStopDelay} = int($self->{childStopDelay} * 1000000);
    $self->{childStopTries} ||= 10;
    $self->{parent} = 1;
    $self->{childs} = [];

    unless ($self->canRun()) {
        require Carp;
        Carp::confess('Couldn\'t run, some other instance is running');
    }

    return $self;
}

###############################################################################
# Daemonize current process: fork, start new session, close STDIN/STDOUT/STDERR, send all output to /dev/null.
#
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

    close(STDIN);
    close(STDOUT);
    close(STDERR);

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

###############################################################################
# Prepare daemon. Must be called before 'run' method.
#
sub prepare {
    my $self = shift;

    if ($self->{detached}) {
        $self->daemonize();
    }

    unless ($self->writePid()) {
        $self->error('Can\'t write pid');
        exit(1);
    }
}

###############################################################################
# Fork daemon. Must be called before 'run' method and after 'prepare' method.
# Forking can be done only in parent process and as many times as you want.
# Childs can't have their own childs.
#
# Returns:
#     0/1 flag. If set, this is forked child process, otherwise - parent one.
#
sub fork {
    my $self = shift;

    unless ($self->{parent}) {
        return 0;
    }

    my $pid = fork();
    if ($pid != 0) {
        push @{$self->{childs}}, $pid;
        return 0;
    }

    unless (defined($pid)) {
        $self->error('Can\'t fork: ' . $!);
        exit(1);
    }

    $self->{parent} = 0;

    return 1;
}

###############################################################################
# Run daemon loop.
#
sub run {
    my $self = shift;

    $self->debug('Started');

    $self->stopOnSignal();

    if ($self->{parent}) {
        $SIG{CHLD} = sub {$self->childStopped()};
    }

    $self->{running} = 1;
    while ($self->{running}) {
        eval {
            $self->{processor}->process();
        };

        if ($@) {
            $self->error('Process error: ' . $@);
        }

        usleep($self->{delay}) if $self->{running} and $self->{delay};
    }

    if ($self->{parent}) {
        $self->stopAllChilds();
        unless ($self->deletePid()) {
            $self->error('Can\'t delete pid file');
        }
    }

    $self->debug('Stopped');

    delete $self->{processor};
}

###############################################################################
# Set daemon's stop flag so its loop will break on next iteration.
#
sub stop {
    my $self = shift;
    $self->debug('Stopping by signal');
    $self->{running} = 0;
}

###############################################################################
# Set handler for all known interruption signals to set daemon's stop flag so its loop will break on next iteration.
#
sub stopOnSignal {
    my $self = shift;
    $SIG{STOP} = $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {$self->stop()};
}

###############################################################################
# Called in parent process and used to stop all child processes.
#
sub stopAllChilds {
    my $self = shift;

    my $try = 0;
    while (scalar(@{$self->{childs}}) > 0) {
        if ($try >= $self->{childStopTries}) {
            $self->error('Can\'t stop all childs, remained: ' . join(', ', @{$self->{childs}}));
            last;
        }
        foreach my $child (@{$self->{childs}}) {
            kill TERM => $child;
        }
        usleep($self->{childStopDelay});
        $try++;
    }
}

###############################################################################
# Called in parent process on signal 'CHLD' which is sent when some child had stopped.
# Remove here its pid from internal childs array.
#
sub childStopped {
    my $self = shift;
    while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        $self->{childs} = [ grep {$_ != $pid} @{$self->{childs}} ];
    }
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
    $self->{logger}->debug($message);
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
    $self->{logger}->error($message);
}

###############################################################################
# Read current value from pid file.
#
# Returns:
#     integer pid value or 0 if pid file does not exists or contains not a number.
#
sub readPid {
    my $self = shift;
    return (-s $self->{pidfile}) ? readInt($self->{pidfile}) : 0;
}

###############################################################################
# Write pid file of current process to pid file.
#
# Returns:
#     1/undef on success/error accordingly.
#
sub writePid {
    my $self = shift;

    unless (writeInt($self->{pidfile}, $$)) {
        return undef;
    }

    unless (chmod(0666, $self->{pidfile})) {
        return undef;
    }

    return 1;
}

###############################################################################
# Delete pid file.
#
# Returns:
#     1/undef on success/error accordingly.
#
sub deletePid {
    my $self = shift;

    if (-e $self->{pidfile}) {
        unless (unlink($self->{pidfile})) {
            return undef;
        }
    }

    return 1;
}

###############################################################################
# Check if daemon can be run assuming only one instance of it can.
#
# Returns:
#     0/1 flag which will be set if daemon can safely run.
#
sub canRun {
    my $self = shift;

    if (my $pid = $self->readPid()) {
        return isProcessRunning($pid, $self->{script}) ? 0 : 1;
    }

    return 1;
}

###############################################################################
# Read integer value from given file.
#
# Arguments:
#     fileName - name of file to read from.
# Returns:
#     integer value or 0 if file can't be opened or its content is not integer.
#
sub readInt {
    my $fileName = shift;

    my $fh;
    unless (open($fh, '<', $fileName)) {
        return 0;
    }
    my $value = <$fh>;
    close($fh);

    if (looks_like_number($value)) {
        $value = int($value);
    } else {
        $value = 0;
    }

    return $value;
}

###############################################################################
# Write integer value to file.
#
# Arguments:
#     fileName - name of file to write to.
#     value    - integer value to write.
# Returns:
#     1/undef on success/error accordingly.
#
sub writeInt {
    my $fileName = shift;
    my $value = shift;

    my $fh;
    unless (open($fh, '>', $fileName)) {
        return undef;
    }
    print $fh $value;
    close($fh);

    return 1;
}


###############################################################################
# Check if process with given pid and executable file is running now.
#
# Arguments:
#     pid      - pid of checked process.
#     fileName - name of checked process executable file. If undefined given check will be performed only by pid.
# Returns:
#     0/1 flag which will be set if process is currently running.
#
sub isProcessRunning {
    my $pid = shift;
    my $fileName = shift;

    unless (defined($pid) and $pid != 0) {
        return undef;
    }

    my $procFile = '/proc/' . $pid . '/cmdline';
    unless (-e $procFile) {
        return undef;
    }

    unless (defined($fileName)) {
        return 1;
    }

    my $fh;
    unless (open($fh, '<', $procFile)) {
        return undef;
    }
    my $str = <$fh>;
    close($fh);

    unless (defined($str) and $str ne '') {
        return undef;
    }

    if (index($str, $fileName) != -1) {
        return 1;
    }

    return undef;
}

1;
