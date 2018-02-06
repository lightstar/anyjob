package AnyJob::Config::Base;

###############################################################################
# Base class for config object which actually can be used for some other config, not necessarily anyjob-related.
#
# Config is read from file(s) and must be organized into sections, i.e.:
#     [section1]
#     name1 = value1
#     name2 = value2
#
#     [section2]
#     ...
#
# By default all values must be on one line but you can use slash in the end of line to prolong it or
# 'here document' syntax to include some large snipped as value. Examples:
#     name1 = some long \
#             value
#
#     name2 = <<END
#         some event more
#         long value
#     END
#
# Also config file can include comments beginning with symbol '#'.
#
# Author:       LightStar
# Created:      19.10.2017
# Last update:  06.02.2018
#

use strict;
use warnings;
use utf8;

###############################################################################
# Construct new AnyJob::Config::Base object.
#
# Arguments:
#     fileName      - string name of root file with config.
#     globalSection - optional string with name of global section which will be used as default section name and
#                     by AUTOLOAD when you will try to retrieve some value without providing section name.
# Returns:
#     AnyJob::Config::Base object.
#
sub new {
    my $class = shift;
    my $fileName = shift;
    my $globalSection = shift;

    my $self = bless {}, $class;
    $self->{global} = $globalSection;
    $self->{data} = {};
    $self->addConfig($fileName, $globalSection);

    return $self;
}

###############################################################################
# Add config data using provided file name and section.
#
# Arguments:
#     fileName      - string name of file which contains config.
#     fileSection   - optional string with name of section into which all data without section will be added.
#                     All those data will be skipped if this argument is undefined.
#
sub addConfig {
    my $self = shift;
    my $fileName = shift;
    my $fileSection = shift;

    my $data = $self->readFile($fileName, $fileSection);
    while (my ($section, $var) = each(%$data)) {
        $self->{data}->{$section} ||= {};
        while (my ($key, $val) = each(%$var)) {
            $self->{data}->{$section}->{$key} = $val;
        }
    }
}

###############################################################################
# Read config data using provided file name and section.
#
# Arguments:
#     fileName      - string name of file which contains config.
#     fileSection   - optional string with name of section into which all data without section will be added.
#                     All those data will be skipped if this argument is undefined.
# Returns:
#     hash with config data in form:
#         {
#             section1 => {
#                 name1 => 'value1',
#                 name2 => 'value2',
#                 ...
#             },
#             section2 => {
#                 ...
#             }
#         }
#
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
                $data->{$section} ||= {};
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

###############################################################################
# Get section data as hash.
#
# Arguments:
#     section - string name of section.
# Returns:
#     hash with section data or undef if section does not exists.
#
sub section {
    my $self = shift;
    my $section = shift || '';
    return $self->{data}->{$section};
}

###############################################################################
# AUTOLOAD method which returns hash with section data or string value in global section by provided name.
# Returns undef if nothing of those exists.
#
# DESTROY method is provided only because AUTOLOAD will not work without it.
#
sub DESTROY {}
our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    (my $name = $AUTOLOAD) =~ s/.*://;

    if (exists($self->{data}->{$name})) {
        return $self->{data}->{$name};
    }

    if (defined($self->{global}) and exists($self->{data}->{$self->{global}}->{$name})) {
        return $self->{data}->{$self->{global}}->{$name};
    }

    return undef;
}

1;
