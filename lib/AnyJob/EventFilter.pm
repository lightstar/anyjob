package AnyJob::EventFilter;

use strict;
use warnings;
use utf8;

use JavaScript::Duktape;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;

    if (defined($self->{filter})) {
        $self->{js} = JavaScript::Duktape->new();
        $self->{js}->eval('function eventFilter() { return ' . $self->{filter} . '; }');
    }

    return $self;
}

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
