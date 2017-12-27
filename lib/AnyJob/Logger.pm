package AnyJob::Logger;

###############################################################################
# Primitive logger class. It is singleton so only one instance is created.
# Can log via syslog or by direct print to STDERR/STDOUT.
#
# Author:       LightStar
# Created:      19.10.2017
# Last update:  01.12.2017
#

use strict;
use warnings;
use utf8;

use Sys::Syslog qw(openlog syslog closelog);

use AnyJob::DateTime qw(formatDateTime);

###############################################################################
# AnyJob::Logger instance object or undef.
#
my $logger;

###############################################################################
# Get AnyJob::Logger object or undef if it is not created yet.
#
# Returns:
#     AnyJob::Logger object or undef.
#
sub get {
    return $logger;
}

###############################################################################
# Construct new AnyJob::Logger object or return previously created one.
#
# Arguments:
#     type    - string component's type added to each log message. Must not be empty.
#     syslog  - 0/1 flag. Will use syslog if it's set.
#     develop - 0/1 flag. If set, logger will use develop syslog tag.
# Returns:
#     AnyJob::Logger object.
#
sub new {
    if (defined($logger)) {
        return $logger;
    }

    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{type}) and $self->{type} ne '') {
        require Carp;
        Carp::confess('No component type provider');
    }

    if ($self->{syslog}) {
        my $tag = ($self->{develop} ? 'anyjob-dev' : 'anyjob') . ($self->{type} ? '-' . $self->{type} : '');
        openlog($tag, 'ndelay,nofatal,pid', 'local0');
    }

    $logger = $self;
    return $self;
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

    if (utf8::is_utf8($message)) {
        utf8::decode($message);
    }

    if ($self->{syslog}) {
        syslog('info', $message);
    } else {
        {
            local $| = 1;
            print STDOUT $self->prefix . $message . "\n";
        }
    }
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

    if (utf8::is_utf8($message)) {
        utf8::decode($message);
    }

    if ($self->{syslog}) {
        syslog('err', $message);
    } else {
        {
            local $| = 1;
            print STDERR $self->prefix . $message . "\n";
        }
    }
}

###############################################################################
# Prefix added to each log message.
#
sub prefix {
    my $self = shift;
    return '[' . formatDateTime() . '] anyjob-' . $self->{type} . '[' . $$ . ']: ';
}

###############################################################################
# Automatically called by perl when object is destroyed.
# As variable containing this object is global, it will never be called but include it here for cleaness.
#
sub DESTROY {
    my $self = shift;
    if ($self->{syslog}) {
        closelog();
    }
}

1;
