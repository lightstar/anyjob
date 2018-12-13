package AnyJob::Creator::Addon::Slack;

###############################################################################
# Addon that helps creating jobs and observing them using slack application (https://slack.com/).
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  13.12.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;
use AnyEvent::HTTP;
use Template;
use Scalar::Util qw(weaken);

use AnyJob::Constants::Events qw(EVENT_TYPE_JOB EVENT_GET_DELAYED_WORKS);
use AnyJob::Constants::Delay;
use AnyJob::Utils qw(getModuleName requireModule);
use AnyJob::Events qw(getEventType);
use AnyJob::DateTime qw(formatDateTime);

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
# Check if given slack user is allowed to use creator.
#
# Arguments:
#     user - string user id.
# Returns:
#     0/1 flag. If set, access is permitted.
#
sub isUserAllowed {
    my $self = shift;
    my $user = shift;

    my $users;

    if (exists($self->{users})) {
        $users = $self->{users};
    } else {
        my $config = $self->config->getCreatorConfig('slack') || {};
        if (exists($config->{users})) {
            $users = { map {$_ => 1} split(/\s*,\s*/, $config->{users}) };
        }
        $self->{users} = $users;
    }

    unless (defined($users)) {
        return 1;
    }

    if (defined($user) and exists($users->{$user})) {
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
    eval {
        requireModule($module);
    };
    if ($@) {
        $self->error('Error loading module \'' . $module . '\': ' . $@);
        return undef;
    }

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
# Method which will be called by AnyJob::Creator::Observer when new service event arrives.
#
# Arguments:
#     event - hash with event data.
#
sub receiveServiceEvent {
    my $self = shift;
    my $event = shift;

    $self->parent->setBusy(1);

    my ($name) = split(/:/, $event->{props}->{service});

    my $builder = $self->getBuilder($name);
    if (defined($builder)) {
        $builder->receiveServiceEvent($event);
    }

    $self->parent->setBusy(0);
}

###############################################################################
# Method which will be called by AnyJob::Creator::Observer when new private event arrives.
#
# Arguments:
#     event - hash with event data.
#
sub receivePrivateEvent {
    my $self = shift;
    my $event = shift;

    $self->parent->setBusy(1);

    if ($self->eventFilter($event) and defined(my $url = $event->{props}->{response_url})) {
        my $payload = $self->getEventPayload($event);

        weaken($self);
        http_post($url, $payload, headers => {
            'Content-Type' => 'application/json; charset=utf-8'
        }, sub {
            my ($body, $headers) = @_;
            if (defined($self) and $headers->{Status} !~ /^2/) {
                $self->parent->setBusy(1);
                $self->error('Error sending event to ' . $url . ', response: ' . $body);
                $self->parent->setBusy(0);
            }
        });
    }

    $self->parent->setBusy(0);
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

    $self->preprocessEvent($event);

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

###############################################################################
# Prepare private observer event for further processing.
# Inject 'job' (hash with job configuration if this is job-related event), check access to incoming delayed works
# and format times.
#
# Arguments:
#     event  - hash with event data.
#
sub preprocessEvent {
    my $self = shift;
    my $event = shift;

    my $eventType = getEventType($event->{event});
    if (defined($eventType) and $eventType eq EVENT_TYPE_JOB and exists($event->{type})) {
        $event->{job} = $self->config->getJobConfig($event->{type});
    }

    if (exists($event->{works})) {
        if ($event->{event} eq EVENT_GET_DELAYED_WORKS and exists($event->{props}->{user})) {
            my $user = $event->{props}->{user};
            $event->{works} = [ grep {$self->checkDelayedWorkAccess($user, DELAY_ACTION_GET, $_)} @{$event->{works}} ];
        }

        foreach my $work (@{$event->{works}}) {
            if (exists($work->{time})) {
                $work->{time} = formatDateTime($work->{time});
            }
            if (exists($work->{props}->{time})) {
                $work->{props}->{time} = formatDateTime($work->{props}->{time});
            }
        }
    }
}

1;
