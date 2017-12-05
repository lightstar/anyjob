package AnyJob::Controller::Observer::Slack;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Spec;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Template;

use base 'AnyJob::Controller::Observer::Base';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);

    $self->{tt} = Template->new({
        INCLUDE_PATH => File::Spec->catdir($self->config->getTemplatesPath(), 'observers/slack'),
        ENCODING     => 'UTF-8',
        PRE_CHOMP    => 1,
        POST_CHOMP   => 1,
        TRIM         => 1
    });

    $self->{ua} = LWP::UserAgent->new();
    $self->{ua}->timeout(15);

    return $self;
}

sub processEvent {
    my $self = shift;
    my $event = shift;

    my $config = $self->getObserverConfig();

    unless ($self->preprocessEvent($config, $event)) {
        return;
    }

    unless (defined($config->{url})) {
        require Carp;
        Carp::confess('No destination URL');
    }

    $self->logEvent($event);

    my $request = POST($config->{url},
        Content_Type => 'application/json; charset=utf-8',
        Content      => $self->getPayload($config, $event)
    );

    my $result = $self->{ua}->request($request);
    unless ($result->is_success) {
        $self->error('Error sending event to ' . $config->{url} . ', response: ' . $result->content);
    }
}

sub preprocessEvent {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    unless ($self->SUPER::preprocessEvent($config, $event)) {
        return 0;
    }

    if ($self->checkEventProp($event, 'noslack', 0)) {
        return 0;
    }

    return 1;
}

sub getPayload {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    my $payload = '';

    my $payloadTemplate = $config->{payload_template} || 'payload';
    unless ($self->{tt}->process($payloadTemplate . '.tt', $event, \$payload)) {
        require Carp;
        Carp::confess('Can\'t process template \'' . $payloadTemplate . '\': ' . $self->{tt}->error());
    }

    utf8::encode($payload);
    return $payload;
}

1;
