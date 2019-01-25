package AnyJob::Crontab::Set::Base;

###############################################################################
# Arbitrary set of integers designated by specification string in crontab-based format and some bounded range.
# Specification string is comma-separated list of numbers and ranges (in <min>-<max> form or just '*' character to
# designate entire range). Ranges can also have optional step designated by slash character and number.
# Example: 3,5,8-10,*/5
#
# This class is used as base for all other crontab set classes.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use AnyJob::Constants::Functions qw(IDENTITY_FN TRUE_FN);

###############################################################################
# Construct new AnyJob::Crontab::Set::Base object.
#
# Arguments:
#     spec   - specification string in crontab-based format.
#     range  - array of integers used as total range for resulting set.
#     mapper - optional function used to map each value in specification string to corresponding number.
#     filter - optional function used to additionally filter out numbers from set.
# Returns:
#     AnyJob::Crontab::Set::Base object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{spec}) and $self->{spec} ne '') {
        require Carp;
        Carp::confess('No specification');
    }

    unless (defined($self->{range}) and ref($self->{range}) eq 'ARRAY' and scalar(@{$self->{range}}) > 0) {
        require Carp;
        Carp::confess('No range');
    }

    unless (defined($self->{mapper})) {
        $self->{mapper} = IDENTITY_FN;
    }

    unless (defined($self->{filter})) {
        $self->{filter} = TRUE_FN;
    }

    $self->init();

    return $self;
}

###############################################################################
# Get set data.
#
# Returns:
#     set data as array of integers.
#
sub getData {
    my $self = shift;
    return $self->{data};
}

###############################################################################
# Initialize set data. Throw exception if it is not possible or set is empty.
#
sub init {
    my $self = shift;

    my $range = $self->{range};
    my $filter = $self->{filter};

    if ($self->{spec} eq '*' and $filter == TRUE_FN) {
        $self->{data} = $range;
        return;
    }

    my %hash;
    my %rangeHash = map {$_ => 1} @{$range};

    foreach my $item (grep {$_ ne ''} split(/\s*,\s*/, $self->{spec})) {
        my ($spec, $step) = $self->parseItem($item);

        if ($spec eq '*') {
            for my $value (@{$range}) {
                if ($value % $step == 0 and $filter->($value)) {
                    $hash{$value} = 1;
                }
            }
        } elsif ($spec =~ /^([^\-]+)-([^\-]+)$/) {
            my ($begin, $end) = ($self->parseValue($1), $self->parseValue($2));
            for my $value ($begin .. $end) {
                if (exists($rangeHash{$value}) and $value % $step == 0 and $filter->($value)) {
                    $hash{$value} = 1;
                }
            }
        } else {
            my $value = $self->parseValue($spec);
            if (exists($rangeHash{$value}) and $filter->($value)) {
                $hash{$value} = 1;
            }
        }
    }

    if (scalar(keys(%hash)) == 0) {
        require Carp;
        Carp::confess('No values');
    }

    $self->{data} = [ sort {$a <=> $b} keys(%hash) ];
}

###############################################################################
# Parse one item from specification string. Throw exception if it is not possible.
#
# Arguments:
#     item - string with just one item in comma-separated input list optionally with step.
# Returns:
#     string with that same item excluding step part.
#     integer step or number '1' if step is absent.
#
sub parseItem {
    my $self = shift;
    my $item = shift;

    my ($spec, $step) = ($item =~ /^([^\/]+)(?:\/(\d+))?$/);

    unless (defined($spec)) {
        require Carp;
        Carp::confess('Wrong specification format');
    }

    if (defined($step)) {
        $step = int($step);
    }
    $step ||= 1;

    return +($spec, $step);
}

###############################################################################
# Parse value from specification string which should be integer number (possibly after mapping).
# Throw exception if it is not the case.
#
# Arguments:
#     value - string with value in specification string.
# Returns:
#     integer value.
#
sub parseValue {
    my $self = shift;
    my $value = shift;

    $value = $self->{mapper}->($value);

    if ($value !~ /^\d+$/) {
        require Carp;
        Carp::confess('Wrong specification format');
    }

    return int($value);
}

1;
