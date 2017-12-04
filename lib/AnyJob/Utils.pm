package AnyJob::Utils;

###############################################################################
# Various utility functions.
#
# Author:       LightStar
# Created:      27.10.2017
# Last update:  04.12.2017
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    getModuleName
    requireModule
    getFileContent
    );

###############################################################################
# Get canonical module name from some name in config.
#
# Returns:
#     string module name.
#
sub getModuleName {
    my $name = shift;
    return join('', map {ucfirst($_)} split(/_/, $name));
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

1;
