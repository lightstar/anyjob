package AnyJob::BaseConfig;

use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my $filename = shift;
    my $global = shift;

    my $self = bless {}, $class;
    $self->{global} = $global;
    $self->{data} = {};
    $self->addConfig($filename);

    return $self;
}

sub addConfig {
    my $self = shift;
    my $filename = shift;

    my $data = $self->readFile($filename);
    while (my ($section, $var) = each(%$data)) {
        $self->{data}->{$section} = {};
        while (my ($key, $val) = each(%$var)) {
            $self->{data}->{$section}->{$key} = $val;
        }
    }
}

sub section {
    my $self = shift;
    my $section = shift || "";
    return $self->{data}->{$section};
}

sub readFile {
    my $self = shift;
    my $filename = shift;

    my $fh;
    my $data = {};
    if (open($fh, "<", $filename)) {
        binmode $fh, ":utf8";
        my $section;
        my $var;
        while (my $str = <$fh>) {
            $str =~ s/^\s+//;
            $str =~ s/\s+$//;
            next if $str =~ /^\#/;
            unless ($var) {
                $var = $str;
            } else {
                $var .= $str;
            }
            if ($var =~ s/\\$//) {
                next;
            }
            if (my ($newSection) = ($var =~ /^\[([^\[\]]+)\]$/)) {
                $section = $newSection;
                $data->{$section} = {};
            } elsif (my ($key, $val) = ($var =~ /([^=]+)\=(.+)/)) {
                next unless $section;
                $key =~ s/^\s+//;
                $key =~ s/\s+$//;
                $val =~ s/^\s+//;
                $val =~ s/\s+$//;
                $data->{$section}->{$key} = $val;
            }
            $var = undef;
        }
        close($fh);
    } else {
        require Carp;
        Carp::confess("Can't open '$filename': $!");
    }

    return $data;
}

sub DESTROY {}
our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    (my $name = $AUTOLOAD) =~ s/.*://;

    if (exists($self->{data}->{$name})) {
        return $self->{data}->{$name};
    }

    if ($self->{global} and exists($self->{data}->{$self->{global}}->{$name})) {
        return $self->{data}->{$self->{global}}->{$name};
    }

    return undef;
}

1;
