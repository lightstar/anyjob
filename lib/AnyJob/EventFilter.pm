package AnyJob::EventFilter;

###############################################################################
# Class used to filter events by using some javascript-written filter.
# That filter is running under javascript runtime (duktape engine) with injected 'event' object.
# Filter code must be all-in-one value which will evaluate to true or false.
# Wrap it into anonymous function call if you must include some complex logic.
# Examples:
#    event.event != 'progress'
#    (function() { return event.event != 'progress'; })()
#
# Author:       LightStar
# Created:      28.11.2017
# Last update:  01.12.2017
#

use strict;
use warnings;
use utf8;

###############################################################################
# Construct new AnyJob::EventFilter object.
#
# Arguments:
#     filter - string with javascript-written filter or undef. If not defined no filter will be used and run.
# Returns:
#     AnyJob::EventFilter object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    if (defined($self->{filter})) {
        require JavaScript::Duktape;
        $self->{js} = JavaScript::Duktape->new();
        $self->{js}->eval('function eventFilter() { return ' . $self->{filter} . '; }');
    }

    return $self;
}

###############################################################################
# Evaluate filter.
#
# Arguments:
#     event - hash with event data.
# Returns:
#     0/1 flag determining result of evaluating filter.
#     Will just return '1' if no filter string was defined.
#
sub filter {
    my $self = shift;
    my $event = shift;

    unless (exists($self->{js})) {
        return 1;
    }

    $self->{js}->set('event', $event);
    return $self->{js}->eval('eventFilter()') ? 1 : 0;
}

1;
