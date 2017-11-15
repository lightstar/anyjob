package AnyJob::Utils;

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    moduleName
    getFileContent
    );

sub moduleName {
    my $name = shift;
    return join("", map {ucfirst($_)} split(/_/, $name));
}

sub getFileContent {
    my $fileName = shift;

    my $content;

    my $fh;
    if (open($fh, "<", $fileName)) {
        binmode $fh, ":utf8";
        {
            local $/ = undef;
            $content = <$fh>;
        }
        close($fh);
    }

    unless (defined($content)) {
        $content = "";
    }

    return $content;
}

1;
