package AnyJob::Utils;

###############################################################################
# Various utility functions.
#
# Author:       LightStar
# Created:      27.10.2017
# Last update:  05.03.2018
#

use strict;
use warnings;
use utf8;

use Scalar::Util qw(looks_like_number);

use base 'Exporter';

our @EXPORT_OK = qw(
    getModuleName
    requireModule
    getFileContent
    readInt
    writeInt
    isProcessRunning
    );

###############################################################################
# Get canonical module name from some name in config.
#
# Returns:
#     string module name.
#
sub getModuleName {
    my $name = shift;
    return join('::', map {ucfirst($_)} split(/\//, join('', map {ucfirst($_)} split(/_/, $name))));
}

###############################################################################
# Load module by name using eval and throwing exception on error.
#
# Arguments:
#     module - string module name.
#
sub requireModule {
    my $module = shift;

    eval 'require ' . $module;
    if ($@) {
        require Carp;
        Carp::confess('Can\'t load module \'' . $module . '\': ' . $@);
    }
}

###############################################################################
# Get full file content.
#
# Arguments:
#     fileName - string file name.
# Returns:
#     string file content or empty string if file can't be opened.
#
sub getFileContent {
    my $fileName = shift;

    my $content;

    my $fh;
    if (open($fh, '<', $fileName)) {
        binmode $fh, ':utf8';
        {
            local $/ = undef;
            $content = <$fh>;
        }
        close($fh);
    }

    unless (defined($content)) {
        $content = '';
    }

    return $content;
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
#     fileName - name of checked process executable file. If undef, given check will be performed only by pid.
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
