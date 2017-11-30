package AnyJob::Creator::Addon::Web;

use strict;
use warnings;
use utf8;

use File::Spec;
use Scalar::Util qw(reftype);
use AnyEvent;

use AnyJob::Utils qw(getFileContent);
use AnyJob::Constants::Defaults qw(DEFAULT_DELAY);

use base 'AnyJob::Creator::Addon::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'web';
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub checkAuth {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    my $config = $self->config->section('creator_web_auth') || {};
    return (exists($config->{$user}) and crypt($pass, $config->{$user}) eq $config->{$user}) ? 1 : 0;
}

sub getEventTemplate {
    my $self = shift;

    unless (exists($self->{appEventTemplate})) {
        $self->{appEventTemplate} =
            getFileContent(File::Spec->catdir($self->config->templates_path, 'observers/app/web/event.html'));
    }

    return $self->{appEventTemplate};
}

sub preprocessJobs {
    my $self = shift;
    my $jobs = shift;

    if (ref($jobs) ne 'ARRAY' or scalar(@$jobs) == 0) {
        return;
    }

    foreach my $job (@$jobs) {
        if (defined($job->{params}) and ref($job->{params}) eq 'HASH') {
            $self->preprocessJobParams($job->{params});
        }

        if (defined($job->{props}) and ref($job->{props}) eq 'HASH') {
            $self->preprocessJobParams($job->{props});
        }
    }
}

sub preprocessJobParams {
    my $self = shift;
    my $params = shift;

    while (my ($name, $value) = each(%$params)) {
        if (ref($value) ne '' and reftype($value) eq 'SCALAR') {
            $params->{$name} = $$value;
        }
    }
}

sub observePrivateEvents {
    my $self = shift;
    my $conn = shift;
    my $user = shift;

    my $config = $self->config->section('creator_web') || {};
    my $delay = $config->{observer_delay} || DEFAULT_DELAY;
    my $timer = AnyEvent->timer(after => $delay, interval => $delay, cb => sub {
            $self->parent->setBusy(1);

            my $events = $self->filterEvents(
                $self->parent->receivePrivateEvents('u' . $user, 'stripInternalProps')
            );

            if (scalar(@$events) > 0) {
                $conn->send($events);
            }

            $self->parent->setBusy(0);
        });
    $conn->on(close => sub {
            undef $timer;
        });
}

1;
