package AnyJob::Logger;

use strict;
use warnings;
use utf8;

use Sys::Syslog qw(openlog syslog closelog);

use AnyJob::DateTime qw(formatDateTime);

my $logger;

sub get {
    return $logger;
}

sub new {
    if (defined($logger)) {
        return $logger;
    }

    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    if ($self->{syslog}) {
        openlog("anyjob" . ($self->{type} ? "-" . $self->{type} : ""), "ndelay,nofatal,pid", "local0");
    }

    return $self;
}

sub debug {
    my $self = shift;
    my $message = shift;

    if (utf8::is_utf8($message)) {
        utf8::decode($message);
    }

    if ($self->{syslog}) {
        syslog("info", $message);
    } else {
        {
            local $| = 1;
            print STDOUT $self->prefix . $message . "\n";
        }
    }
}

sub error {
    my $self = shift;
    my $message = shift;

    if (utf8::is_utf8($message)) {
        utf8::decode($message);
    }

    if ($self->{syslog}) {
        syslog("err", $message);
    } else {
        {
            local $| = 1;
            print STDERR $self->prefix . $message . "\n";
        }
    }
}

sub prefix {
    my $self = shift;
    return "[" . formatDateTime() . "] anyjob-" . $self->{type} . "[" . $$ . "]: ";
}

sub DESTROY {
    my $self = shift;
    if ($self->{syslog}) {
        closelog();
    }
}

1;
