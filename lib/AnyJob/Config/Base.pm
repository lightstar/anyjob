package AnyJob::Config::Base;

use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my $fileName = shift;
    my $globalSection = shift;

    my $self = bless {}, $class;
    $self->{global} = $globalSection;
    $self->{data} = {};
    $self->addConfig($fileName);

    return $self;
}

sub addConfig {
    my $self = shift;
    my $fileName = shift;
    my $fileSection = shift;

    my $data = $self->readFile($fileName, $fileSection);
    while (my ($section, $var) = each(%$data)) {
        $self->{data}->{$section} = {};
        while (my ($key, $val) = each(%$var)) {
            $self->{data}->{$section}->{$key} = $val;
        }
    }
}

sub section {
    my $self = shift;
    my $section = shift || '';
    return $self->{data}->{$section};
}

sub readFile {
    my $self = shift;
    my $fileName = shift;
    my $fileSection = shift;

    my $data = {};
    if ($fileSection) {
        $data->{$fileSection} = {};
    }

    my $fh;
    if (open($fh, '<', $fileName)) {
        binmode $fh, ':utf8';
        my $section = $fileSection;
        my $var;
        my $docMarker;
        while (my $str = <$fh>) {
            $str =~ s/^\s+//;
            $str =~ s/\s+$//;
            next if $str =~ /^\#/;

            unless (defined($var)) {
                $var = $str;
            } else {
                $var .= $str;
            }

            unless (defined($docMarker)) {
                ($docMarker) = ($var =~ /<<([A-Z\d]+)$/);
                if (defined($docMarker)) {
                    $var =~ s/<<$docMarker$//;
                    next;
                }
            }

            if (defined($docMarker)) {
                if ($str ne $docMarker) {
                    $var .= "\n";
                    next;
                } else {
                    $var =~ s/$docMarker$//;
                    $docMarker = undef;
                }
            }

            if ($var =~ s/\\$//) {
                next;
            }

            if (my ($newSection) = ($var =~ /^\[([^\[\]]+)\]$/)) {
                $section = $newSection;
                $data->{$section} = {};
            } elsif (my ($key, $val) = ($var =~ /^([^=]+)\=(.+)$/s)) {
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
        Carp::confess('Can\'t open \'' . $fileName . '\': ' . $!);
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
