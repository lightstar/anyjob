package AnyJob::Controller::Observer::Mail;

use strict;
use warnings;
use utf8;

use JSON::XS;
use File::Spec;
use MIME::Base64;
use MIME::Entity;
use Template;

use AnyJob::DateTime qw(formatDateTime);

use base 'AnyJob::Controller::Observer::Base';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    $self->{tt} = Template->new({
        INCLUDE_PATH => File::Spec->catdir($self->config->path, 'templates/observers/mail'),
        ENCODING     => "UTF-8",
        PRE_CHOMP    => 1,
        POST_CHOMP   => 1,
        TRIM         => 1
    });
    $self->{logs} = {};
    return $self;
}

sub processEvent {
    my $self = shift;
    my $event = shift;
    $self->SUPER::processEvent($event);

    unless ($self->preprocessEvent($event)) {
        return;
    }

    my $config = $self->config->getObserverConfig($self->name);

    unless (defined($config->{from}) and defined($config->{to})) {
        require Carp;
        Carp::confess("No origin or destination address");
    }

    my $letter = MIME::Entity->build(
        From     => '=?UTF-8?B?' . encode_base64($self->getFromTitle($config), '') . '?= <' . $config->{from} . '>',
        To       => '<' . $config->{to} . '>',
        Subject  => '=?UTF-8?B?' . encode_base64($self->getSubject($config, $event), '') . '?=',
        Encoding => 'base64',
        Data     => $self->getBody($config, $event),
        Type     => 'text/html',
        Charset  => 'UTF-8'
    );

    my $fh;
    unless (open($fh, "|/usr/sbin/sendmail -f " . $config->{from} . " -t")) {
        require Carp;
        Carp::confess("Can't open sendmail");
    }
    $letter->print($fh);
    close($fh);
}

sub preprocessEvent {
    my $self = shift;
    my $event = shift;

    if ($event->{event} eq "progress") {
        if ($event->{id} and $event->{progress}->{log}) {
            $self->{logs}->{$event->{id}} ||= [];
            push @{$self->{logs}->{$event->{id}}}, $event->{progress}->{log};
        }
        return 0;
    }

    if ($event->{event} eq "finish") {
        if ($event->{id} and exists($self->{logs}->{$event->{id}})) {
            $event->{log} = $self->{logs}->{$event->{id}};
            delete $self->{logs}->{$event->{id}};
        }
    }

    if ($event->{time}) {
        $event->{time} = formatDateTime($event->{time});
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

    my $subject = "";

    my $subjectTemplate = $config->{subject_template} || 'subject';
    unless ($self->{tt}->process($subjectTemplate . '.tt', $event, \$subject)) {
        require Carp;
        Carp::confess("Can't process template '" . $subjectTemplate . "': " . $self->{tt}->error());
    }

    utf8::encode($subject);
    return $subject;
}

sub getBody {
    my $self = shift;
    my $config = shift;
    my $event = shift;

    my $body = "";

    my $bodyTemplate = $config->{body_template} || 'body';
    unless ($self->{tt}->process($bodyTemplate . '.tt', $event, \$body)) {
        require Carp;
        Carp::confess("Can't process template '" . $bodyTemplate . "': " . $self->{tt}->error());
    }

    utf8::encode($body);
    return $body;
}

1;
