package AnyJob::Controller::Observer::Mail;

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

sub getFromTitle {
    my $self = shift;
    my $config = shift;

    my $fromTitle = $config->{from_title} || 'AnyJob';

    utf8::encode($fromTitle);
    return $fromTitle;
}

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
