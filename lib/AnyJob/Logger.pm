package AnyJob::Logger;

use strict;
use warnings;
use utf8;

use Sys::Syslog qw(openlog syslog closelog);

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
    my ($self, $message) = @_;
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
    my ($self, $message) = @_;
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
    my ($sec, $min, $hour, $day, $month, $year) = (localtime())[0 .. 5];
    $month++;
    $year += 1900;
    my $datetime = sprintf("%.2d-%.2d-%.4d %.2d:%.2d:%.2d", $day, $month, $year, $hour, $min, $sec);
    return "[" . $datetime . "] anyjob-" . $self->{type} . "[" . $$ . "]: ";
}

sub DESTROY {
    my $self = shift;
    if ($self->{syslog}) {
        closelog();
    }
}

1;
