package AnyJob::Creator::Addon::Slack;

###############################################################################
# Addon that helps creating jobs and observing them using slack application (https://slack.com/).
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  07.12.2017
#

use strict;
use warnings;
use utf8;

use File::Spec;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Template;
use AnyEvent;

use AnyJob::Constants::Defaults qw(DEFAULT_DELAY);
use AnyJob::Utils qw(getModuleName requireModule);

use base 'AnyJob::Creator::Addon::Base';

###############################################################################
# Construct new AnyJob::Creator::Addon::Slack object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
# Returns:
#     AnyJob::Creator:Addon::Slack object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'slack';
    my $self = $class->SUPER::new(%args);

    $self->{tt} = Template->new({
        INCLUDE_PATH => File::Spec->catdir($self->config->getTemplatesPath(), 'observers/app/slack'),
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
# Check slack application token which should be sent by slack with each request.
#
# Arguments:
#     token - string token value sent in request.
# Returns:
#     0/1 flag. If set, token is valid.
#
sub checkToken {
    my $self = shift;
    my $token = shift;

    my $config = $self->config->getCreatorConfig('slack') || {};
    if (defined($config->{token}) and defined($token) and $config->{token} eq $token) {
        return 1;
    }

    return 0;
}

###############################################################################
# Get slack builder object by its name. Actually full builder name in configuration will be 'slack_<name>'.
#
# Arguments:
#     name - string builder name.
# Returns:
#     slack builder object (usually subclassed from AnyJob::Creator::Builder::Slack::Base)
#     or undef if it is not exists.
#
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

    my $config = $self->config->getBuilderConfig('slack_' . $name) || {};
    unless (defined($config->{module})) {
        $self->{builders}->{$name} = undef;
        return undef;
    }

    my $module = 'AnyJob::Creator::Builder::Slack::' . getModuleName($config->{module});
    requireModule($module);

    $self->{builders}->{$name} = $module->new(parent => $self->{parent}, name => $name);
    return $self->{builders}->{$name};
}

###############################################################################
# Get slack builder object by slash command name.
# See https://api.slack.com/slash-commands for detailed info about slack slash commands.
#
# Arguments:
#     command - string slash command name.
# Returns:
#     slack builder object (usually subclassed from AnyJob::Creator::Builder::Slack::Base)
#     or undef if it is not exists.
#
sub getBuilderByCommand {
    my $self = shift;
    my $command = shift;

    my $name = $self->getBuilderNameByCommand($command);
    unless (defined($name)) {
        return undef;
    }

    return $self->getBuilder($name);
}

###############################################################################
# Get slack builder name by slash command name.
#
# Arguments:
#     command - string slash command name.
# Returns:
#     string slack builder name.
#
sub getBuilderNameByCommand {
    my $self = shift;
    my $command = shift;

    unless (exists($self->{buildersByCommand})) {
        $self->generateBuildersByCommand();
    }

    return $self->{buildersByCommand}->{$command};
}

###############################################################################
# Generate internal hashmap for fast lookup of slack builder name by name of its slash command.
#
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

###############################################################################
# Execute observing of private events using 'slack' as queue name.
# Observing is done via AnyEvent's timer run with configured interval.
#
sub observePrivateEvents {
    my $self = shift;

    my $config = $self->config->getCreatorConfig('slack') || {};
    my $delay = $config->{observe_delay} || DEFAULT_DELAY;
    $self->{observer_timer} = AnyEvent->timer(after => $delay, interval => $delay, cb => sub {
            $self->parent->setBusy(1);
            $self->sendPrivateEvents($self->parent->receivePrivateEvents('slack'));
            $self->parent->setBusy(0);
        });
}

###############################################################################
# Send messages with private events data to slack users who created corresponding jobs or jobsets.
# Destination address is resolved using special property 'response_url' which should be set for every job and jobset
# created in one of slack builders.
#
# Arguments:
#     events - array of hashes with event data.
#
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

###############################################################################
# Generate message payload for private event by processing configured template.
#
# Arguments:
#     event - hash with event data.
#
# Returns:
#     string message payload.
#
sub getEventPayload {
    my $self = shift;
    my $event = shift;

    if (exists($event->{type})) {
        $event->{job} = $self->config->getJobConfig($event->{type});
    }

    my $config = $self->config->getCreatorConfig('slack') || {};
    my $payloadTemplate = $config->{event_template} || 'payload';

    my $payload = '';
    unless ($self->{tt}->process($payloadTemplate . '.tt', $event, \$payload)) {
        require Carp;
        Carp::confess('Can\'t process template \'' . $payloadTemplate . '\'.tt\': ' . $self->{tt}->error());
    }

    utf8::encode($payload);
    return $payload;
}

1;
