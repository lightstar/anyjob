package AnyJob::Controller::Observer::Mail;

###############################################################################
# Observer controller which sends events by email.
#
# Author:       LightStar
# Created:      24.10.2017
# Last update:  06.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Spec;
use MIME::Base64;
use MIME::Entity;
use Template;

use AnyJob::Constants::Events qw(EVENT_PROGRESS EVENT_FINISH);

use base 'AnyJob::Controller::Observer::Base';

###############################################################################
# Construct new AnyJob::Controller::Observer::Mail object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Daemon object.
#     name   - non-empty string with observer name which is also used as queue name.
# Returns:
#     AnyJob::Controller::Observer::Mail object.
#
sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);

    $self->{tt} = Template->new({
        INCLUDE_PATH => File::Spec->catdir($self->config->getTemplatesPath(), 'observers/mail'),
        ENCODING     => 'UTF-8',
        PRE_CHOMP    => 1,
        POST_CHOMP   => 1,
        TRIM         => 1
    });

    return $self;
}

###############################################################################
# This method will be called by parent class for each event to process.
# Log event data here and send it by email to configured recipients using configured subject/body templates.
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

    unless (defined($config->{from}) and defined($config->{to})) {
        require Carp;
        Carp::confess('No origin or destination address');
    }

    $self->logEvent($event);

    my $from = $config->{from};
    my $fromTitle = encode_base64($self->getFromTitle($config), '');
    my $subject = encode_base64($self->getSubject($config, $event), '');
    my $body = $self->getBody($config, $event);

    foreach my $to (split(/\s*,\s*/, $config->{to})) {
        my $letter = MIME::Entity->build(
            From     => '=?UTF-8?B?' . $fromTitle . '?= <' . $from . '>',
            To       => '<' . $to . '>',
            Subject  => '=?UTF-8?B?' . $subject . '?=',
            Encoding => 'base64',
            Data     => $body,
            Type     => 'text/html',
            Charset  => 'UTF-8'
        );

        my $fh;
        unless (open($fh, '|/usr/sbin/sendmail -f ' . $from . ' -t')) {
            require Carp;
            Carp::confess('Can\'t open sendmail');
        }
        $letter->print($fh);
        close($fh);
    }
}

###############################################################################
# Prepare event for further processing and check if it needs processing at all.
# In addition to base-class logic check 'nomail' property and
# collect logs to send them all together when job is finished.
# Also by default job progress events are not sent at all.
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

    if ($self->checkEventProp($event, 'nomail', 0)) {
        return 0;
    }

    if ($event->{event} eq EVENT_PROGRESS) {
        $self->saveLog($event);

        unless ($config->{mail_progress} or $self->checkEventProp($event, 'mail_progress', 0)) {
            return 0;
        }
    }

    if ($event->{event} eq EVENT_FINISH) {
        $event->{log} = $self->collectLogs($event);
    }

    return 1;
}

###############################################################################
# Get encoded sender title.
#
# Arguments:
#     config - hash with observer configuration.
#
# Returns:
#     string sender title.
#
sub getFromTitle {
    my $self = shift;
    my $config = shift;

    my $fromTitle = $config->{from_title} || 'AnyJob';

    utf8::encode($fromTitle);
    return $fromTitle;
}

###############################################################################
# Generate mail subject by processing configured template.
#
# Arguments:
#     config - hash with observer configuration.
#     event  - hash with event data.
#
# Returns:
#     string mail subject.
#
sub getSubject {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    my $subject = '';

    my $subjectTemplate = $config->{subject_template} || 'subject';
    unless ($self->{tt}->process($subjectTemplate . '.tt', $event, \$subject)) {
        require Carp;
        Carp::confess('Can\'t process template \'' . $subjectTemplate . '\': ' . $self->{tt}->error());
    }

    utf8::encode($subject);
    return $subject;
}

###############################################################################
# Generate mail body by processing configured template.
#
# Arguments:
#     config - hash with observer configuration.
#     event  - hash with event data.
#
# Returns:
#     string mail body.
#
sub getBody {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    my $body = '';

    my $bodyTemplate = $config->{body_template} || 'body';
    unless ($self->{tt}->process($bodyTemplate . '.tt', $event, \$body)) {
        require Carp;
        Carp::confess('Can\'t process template \'' . $bodyTemplate . '\': ' . $self->{tt}->error());
    }

    utf8::encode($body);
    return $body;
}

1;
