#!/usr/bin/perl

###############################################################################
# Tool used to find all clients holding specified semaphore. It accepts semaphore name as argument.
#
# Author:       LightStar
# Created:      19.12.2018
# Last update:  19.12.2018
#

use lib ($ENV{ANYJOB_LIB} || ($ENV{ANYJOB_PATH} || '/opt/anyjob') . '/lib');
use strict;
use warnings;
use utf8;

use AnyJob::Constants::Defaults qw(DEFAULT_ANYJOB_PATH);
use AnyJob::Tool;
use AnyJob::DateTime qw(formatDateTime);

###############################################################################
# Inline directory used by 'Inline' perl module.
#
BEGIN {
    $ENV{PERL_INLINE_DIRECTORY} = ($ENV{ANYJOB_PATH} || DEFAULT_ANYJOB_PATH) . '/.inline';
}

if (scalar(@ARGV) < 1) {
    print 'Usage: semclients <semaphore>' . "\n";
    exit(1);
}

my $tool = AnyJob::Tool->new();

my %clients = $tool->redis->zrangebyscore('anyjob:sem:clients', '-inf', '+inf', 'WITHSCORES');

my $isAnyClient = 0;
foreach my $clientFull (sort {$clients{$a} <=> $clients{$b}} keys(%clients)) {
    my ($name, $client) = ($clientFull =~ /^([^:]+):(.+)$/);
    next unless defined($name) and defined($client) and $name eq $ARGV[0];
    print $client . ' (' . formatDateTime($clients{$clientFull}) . ')' . "\n";
    $isAnyClient = 1;
}

unless ($isAnyClient) {
    print 'No clients' . "\n";
}

exit(0);

1;
