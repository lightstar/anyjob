package AnyJob::Config::Selector::Base;

###############################################################################
# Abstract base class for config selectors. Selectors are used to select and add any additional files and even
# directories into configuration object.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  07.02.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

###############################################################################
# Construct new AnyJob::Config::Selector::Base object.
#
# Arguments:
#     config - AnyJob::Config object.
# Returns:
#     AnyJob::Config::Selector::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{config})) {
        require Carp;
        Carp::confess('No config provided');
    }

    return $self;
}

###############################################################################
# Returns:
#     AnyJob::Config object.
#
sub config {
    my $self = shift;
    return $self->{config};
}

###############################################################################
# Include configuration from provided file if that file really exists.
#
# Arguments:
#     fileName - string relative file name. File name is relative to main configuration base path.
#     section  - optional string default section name for that file.
# Returns:
#     0/1 flag. If set, file exists and config was added.
#
sub addConfigFromFile {
    my $self = shift;
    my $fileName = shift;
    my $section = shift;

    my $fullFileName = File::Spec->catfile($self->config->baseDir, $fileName);
    if (-f $fullFileName) {
        $self->config->addConfig($fullFileName, $section);
        return 1;
    }
    return 0;
}

###############################################################################
# Include configuration from all files in directory with provided name if that directory really exists.
#
# Arguments:
#     dirName - string relative directory name. Directory name is relative to main configuration base path.
#     section - string prefix of default section names for files in that directory. For details see AnyJob::Config
#               class.
# Returns:
#     0/1 flag. If set, directory exists and config was added.
#
sub addConfigFromDir {
    my $self = shift;
    my $dirName = shift;
    my $section = shift;

    my $fullDirName = File::Spec->catdir($self->config->baseDir, $dirName);
    if (-d $fullDirName) {
        $self->config->addConfigFromDir($fullDirName, $section);
        return 1;
    }
    return 0;
}

###############################################################################
# Abstract method which will be called to add all additional files into configuration.
#
sub addConfig {
    my $self = shift;

    require Carp;
    Carp::confess('Need to be implemented in descendant');
}

1;
