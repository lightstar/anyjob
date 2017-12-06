package AnyJob::Controller::Observer::Slack;

###############################################################################
# Observer controller which sends events to slack (https://slack.com/) incoming webhook.
#
# Author:       LightStar
# Created:      25.10.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Spec;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Template;

use base 'AnyJob::Controller::Observer::Base';

###############################################################################
# Construct new AnyJob::Controller::Observer::Slack object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
#     name   - non-empty string with observer name which is also used as queue name.
# Returns:
#     AnyJob::Controller::Observer::Slack object.
#
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

###############################################################################
# This method will be called by parent class for each event to process.
# Log event data here and send it to configured slack incoming webhook using configured payload template.
#
# Arguments:
#     event - hash with event data.
#
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

###############################################################################
# Prepare event for further processing and check if it needs processing at all.
# In addition to base-class logic check 'noslack' property.
#
# Arguments:
#     config - hash with observer configuration.
#     event  - hash with event data.
#
# Returns:
#     0/1 flag. If set, event should be processed, otherwise skipped.
#
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

###############################################################################
# Generate message payload by processing configured template.
#
# Arguments:
#     config - hash with observer configuration.
#     event  - hash with event data.
#
# Returns:
#     string message payload.
#
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
