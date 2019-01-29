package AnyJob::Crontab::Factory;

###############################################################################
# Factory for AnyJob::Crontab::Scheduler objects and instances of internally used crontab set classes.
# All managed instances are cached in memory based on specification strings and additional arguments to minimize
# cpu and memory usage.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  29.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Utils qw(requireModule);
use AnyJob::Crontab::Scheduler;

###############################################################################
# Construct new AnyJob::Crontab::Factory object.
#
# Returns:
#     AnyJob::Crontab::Factory object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    $self->{sets} = {};
    $self->{schedulers} = {};

    return $self;
}

###############################################################################
# Get AnyJob::Crontab::Scheduler object by specification string.
#
# Arguments:
#     spec - crontab specification string.
# Returns:
#     AnyJob::Crontab::Scheduler object or undef in case of error.
#     string error or undef.
#
sub getScheduler {
    my $self = shift;
    my $spec = shift;

    if (exists($self->{schedulers}->{$spec})) {
        return $self->{schedulers}->{$spec};
    }

    my $scheduler;
    eval {
        $scheduler = AnyJob::Crontab::Scheduler->new(factory => $self, spec => $spec);
    };
    if ($@) {
        return +(undef, 'wrong crontab specification');
    }

    $self->{schedulers}->{$spec} = $scheduler;
    return +($scheduler, undef);
}

###############################################################################
# Get instance of one of crontab set classes.
# Throws exception in case of error.
#
# Arguments:
#     type      - string with last part of set module name.
#     spec      - crontab-based specification string.
#     keySuffix - optional string with additional suffix of key used to store resulting instance in cache. That suffix
#                 must uniquely identify all additional arguments.
#     args      - optional hash with additional arguments given to set class constructor.
# Returns:
#     instance of class subclassed from AnyJob::Crontab::Set::Base class.
#
sub getSet {
    my $self = shift;
    my $type = shift;
    my $spec = shift;
    my $keySuffix = shift;
    my $args = shift;

    my $key = $type . '_' . $spec . (defined($keySuffix) ? '_' . $keySuffix : '');
    if (exists($self->{sets}->{$key})) {
        return $self->{sets}->{$key};
    }

    my $module = 'AnyJob::Crontab::Set::' . $type;
    requireModule($module);

    my $set = $module->new(spec => $spec, %{$args || {}});
    $self->{sets}->{$key} = $set;
    return $set;
}

1;
