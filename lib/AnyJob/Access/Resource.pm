package AnyJob::Access::Resource;

###############################################################################
# Class which represents access that some resource requires.
#
# Author:       LightStar
# Created:      08.02.2018
# Last update:  08.02.2018
#

use strict;
use warnings;
use utf8;

###############################################################################
# Access object which signifies that resource doesn't requires any accesses.
#
our $ACCESS_ANY = AnyJob::Access::Resource->new(input => '');

###############################################################################
# Construct new AnyJob::Access::Resource object.
#
# Arguments:
#     input - string input access. Details about its syntax see in documentation.
# Returns:
#     AnyJob::Access::Resource object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{input})) {
        require Carp;
        Carp::confess('No input provided');
    }

    $self->compile();

    return $self;
}

###############################################################################
# Compile input access string into optimized internal representation. Called automatically in constructor.
#
sub compile {
    my $self = shift;

    my $expr = $self->{input};
    $expr =~ s/([a-zA-Z0-9_-]+)/\$userAccess->hasAccess('$1')/g;
    $expr =~ s/,/ and /g;
    $expr =~ s/\|/ or /g;
    $expr =~ s/!/not /g;
    if ($expr eq '') {
        $expr = 1;
    }

    $expr = eval 'sub { my $userAccess = shift; return (' . $expr . ') ? 1 : 0; }';
    if ($@) {
        require Carp;
        Carp::confess('Error compiling access: ' . $@);
    }

    $self->{expr} = $expr;
}

###############################################################################
# Check if user has access to resource.
#
# Arguments:
#     userAccess - AnyJob::Access::User object with user's accesses.
# Returns:
#     0/1 flag. If set, user has access to resource, otherwise - not.
#
sub hasAccess {
    my $self = shift;
    my $userAccess = shift;
    return $self->{expr}->($userAccess);
}

1;
