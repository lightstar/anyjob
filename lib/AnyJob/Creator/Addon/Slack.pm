package AnyJob::Creator::Addon::Slack;

use strict;
use warnings;
use utf8;

use File::Spec;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Template;
use AnyEvent;

use AnyJob::Utils qw(moduleName requireModule);
use AnyJob::Constants::Defaults qw(DEFAULT_DELAY);

use base 'AnyJob::Creator::Addon::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'slack';
    my $self = $class->SUPER::new(%args);

    $self->{tt} = Template->new({
        INCLUDE_PATH => File::Spec->catdir($self->config->templates_path, 'observers/app/slack'),
        ENCODING     => 'UTF-8',
        PRE_CHOMP    => 1,
        POST_CHOMP   => 1,
        TRIM         => 1
    });

    $self->{ua} = LWP::UserAgent->new();
    $self->{ua}->timeout(15);

    return $self;
}

sub checkToken {
    my $self = shift;
    my $token = shift;

    my $config = $self->config->section('creator_slack') || {};
    if (defined($config->{token}) and defined($token) and $config->{token} eq $token) {
        return 1;
    }

    return undef;
}

sub getBuilder {
    my $self = shift;
    my $name = shift;

    unless (defined($name)) {
        return undef;
    }

    if (exists($self->{builders}) and exists($self->{builders}->{$name})) {
        return $self->{builders}->{$name};
    }

    $self->{builders} ||= {};

    my $config = $self->config->getBuilderConfig('slack_' . $name);
    my $module = 'AnyJob::Creator::Builder::Slack::' . moduleName($config->{module});
    requireModule($module);

    $self->{builders}->{$name} = $module->new(parent => $self->{parent}, name => $name);
    return $self->{builders}->{$name};
}

sub getBuilderByCommand {
    my $self = shift;
    my $command = shift;

    my $name = $self->getBuilderNameByCommand($command);
    unless (defined($name)) {
        return undef;
    }

    return $self->getBuilder($name);
}

sub getBuilderNameByCommand {
    my $self = shift;
    my $command = shift;

    unless (exists($self->{buildersByCommand})) {
        $self->generateBuildersByCommand();
    }

    return $self->{buildersByCommand}->{$command};
}

sub generateBuildersByCommand {
    my $self = shift;

    my %builders;
    foreach my $name (@{$self->config->getAllBuilders()}) {
        unless ($name =~ s/^slack_//) {
            next;
        }

        my $config = $self->config->getBuilderConfig('slack_' . $name) || {};
        foreach my $command (grep {$_ ne ''} ($config->{command} || '', split(/\s*,\s*/, $config->{aliases} || ''))) {
            $builders{$command} = $name;
        }
    }

    $self->{buildersByCommand} = \%builders;
}

sub observePrivateEvents {
    my $self = shift;

    my $config = $self->config->section('creator_slack') || {};
    my $delay = $config->{observer_delay} || DEFAULT_DELAY;
    $self->{observer_timer} = AnyEvent->timer(after => $delay, interval => $delay, cb => sub {
            $self->parent->shutdownIfNeeded();
            $self->sendPrivateEvents($self->parent->receivePrivateEvents('slack'));
        });
}

sub sendPrivateEvents {
    my $self = shift;
    my $events = shift;

    foreach my $event (@$events) {
        if ($self->eventFilter($event) and defined(my $url = $event->{props}->{response_url})) {
            my $request = POST($url,
                Content_Type => 'application/json; charset=utf-8',
                Content      => $self->getEventPayload($event)
            );

            my $result = $self->{ua}->request($request);
            unless ($result->is_success) {
                $self->error('Error sending event to ' . $url . ', response: ' . $result->content);
            }
        }
    }
}

sub getEventPayload {
    my $self = shift;
    my $event = shift;

    if (exists($event->{type})) {
        $event->{job} = $self->config->getJobConfig($event->{type});
    }

    my $config = $self->config->section('creator_slack') || {};
    my $payloadTemplate = $config->{event_payload_template} || 'payload';

    my $payload = '';
    unless ($self->{tt}->process($payloadTemplate . '.tt', $event, \$payload)) {
        require Carp;
        Carp::confess('Can\'t process template \'' . $payloadTemplate . '\'.tt\': ' . $self->{tt}->error());
    }

    utf8::encode($payload);
    return $payload;
}

1;
