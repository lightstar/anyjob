package AnyJob::Access::User;

###############################################################################
# Class which represents access that some user has.
#
# Author:       LightStar
# Created:      08.02.2018
# Last update:  08.02.2018
#

use strict;
use warnings;
use utf8;

###############################################################################
# Access object which signifies that user has no accesses.
#
our $ACCESS_NONE = AnyJob::Access::User->new(groups => {}, input => '');

###############################################################################
# Construct new AnyJob::Access::User object.
#
# Arguments:
#     groups - hash with access groups data. Details see in documentation.
#     input  - string input with accesses separated by comma. Details see in documentation.
# Returns:
#     AnyJob::Access::User object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    unless (defined($self->{groups})) {
        require Carp;
        Carp::confess('No groups provided');
    }

    unless (defined($self->{input})) {
        require Carp;
        Carp::confess('No input provided');
    }

    $self->compile();

    return $self;
}

###############################################################################
# Compile input string with accesses separated by comma into optimized internal representation.
# Called automatically in constructor.
#
sub compile {
    my $self = shift;

    $self->{access} = {};
    $self->{except} = {};
    foreach my $item (grep {$_ ne ''} split(/\s*,\s*/, $self->{input})) {
        $self->compileItem($item);
    }
}

###############################################################################
# Compile one access item. Called automatically and used for recursion.
#
# Arguments:
#     item - string access input item (i.e. some group or access name possibly with modifier).
#
sub compileItem {
    my $self = shift;
    my $item = shift;

    my $firstLetter = substr($item, 0, 1);
    if ($firstLetter eq '@') {
        my $group = substr($item, 1);
        if ($group eq 'all') {
            $self->{access}->{'@all'} = 1;
        } elsif ($group ne '' and exists($self->{groups}->{$group})) {
            foreach my $groupItem (grep {$_ ne ''} @{$self->{groups}->{$group}}) {
                $self->compileItem($groupItem);
            }
        }
    } elsif ($firstLetter eq '!') {
        my $access = substr($item, 1);
        if ($access ne '') {
            if (exists($self->{access}->{$access})) {
                delete $self->{access}->{$access};
            }
            $self->{except}->{$access} = 1;
        }
    } else {
        if (exists($self->{except}->{$item})) {
            delete $self->{except}->{$item};
        }
        $self->{access}->{$item} = 1;
    }
}

###############################################################################
# Check if user has some access.
#
# Arguments:
#     access - string access name.
# Returns:
#     0/1 flag. If set, user has that access, otherwise - not.
#
sub hasAccess {
    my $self = shift;
    my $access = shift;
    return (
            (exists($self->{access}->{'@all'}) or exists($self->{access}->{$access})) and
                not exists($self->{except}->{$access})
        ) ? 1 : 0;
}

1;
