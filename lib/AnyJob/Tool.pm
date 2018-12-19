package AnyJob::Tool;

###############################################################################
# Tool component subclassed from AnyJob::Base, which is used by helper tools, such as semexit.pl and
# semclients.pl.
#
# Author:       LightStar
# Created:      19.12.2018
# Last update:  19.12.2018
#

use strict;
use warnings;
use utf8;

use AnyJob::Semaphore::Engine;

use base 'AnyJob::Base';

###############################################################################
# Construct new AnyJob::Tool object.
#
# Returns:
#     AnyJob::Tool object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'tool';
    my $self = $class->SUPER::new(%args);

    $self->{semaphoreEngine} = AnyJob::Semaphore::Engine->new(parent => $self);

    return $self;
}

###############################################################################
# Returns:
#     Semaphores engine which is usually AnyJob::Semaphore::Engine object.
#
sub getSemaphoreEngine {
    my $self = shift;
    return $self->{semaphoreEngine};
}

###############################################################################
# Get semaphore object instance with specified name.
#
# Arguments:
#     name - string semaphore name.
# Returns:
#     AnyJob::Semaphore::Instance object.
#
sub getSemaphore {
    my $self = shift;
    my $name = shift;
    return $self->{semaphoreEngine}->getSemaphore($name);
}

1;
