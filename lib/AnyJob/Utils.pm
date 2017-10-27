package AnyJob::Utils;

use strict;
use warnings;
use utf8;

use base 'Exporter';

our @EXPORT_OK = qw(
    moduleName
    );

sub moduleName {
    my $name = shift;
    return join("", map {ucfirst($_)} split(/_/, $name));
}

1;
