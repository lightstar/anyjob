package AnyJob::EventFilter;

use strict;
use warnings;
use utf8;

use JavaScript::Duktape;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    $self->{js} = JavaScript::Duktape->new();
    $self->{js}->eval('function eventFilter() { return ' . (defined($self->{filter}) ? $self->{filter} : '1') . '; }');

    return $self;
}

sub filter {
    my $self = shift;
    my $event = shift;

    $self->{js}->set('event', $event);
    return $self->{js}->eval('eventFilter()') ? 1 : 0;
}

1;
