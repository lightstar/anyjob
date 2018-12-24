package AnyJob::Creator::Addon::Web;

###############################################################################
# Addon that helps creating jobs and observing them using web application running in browser.
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  24.12.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;
use Scalar::Util qw(reftype refaddr weaken);

use AnyJob::Utils qw(getFileContent);
use AnyJob::Creator::Observer;

use base 'AnyJob::Creator::Addon::Base';

###############################################################################
# Construct new AnyJob::Creator::Addon::Web object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
# Returns:
#     AnyJob::Creator:Addon::Web object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'web';
    my $self = $class->SUPER::new(%args);

    $self->{connsByUser} = {};
    $self->{observersByUser} = {};

    return $self;
}

###############################################################################
# Check if given user is allowed to access web application.
#
# Arguments:
#     user - string user login.
#     pass - string user password.
# Returns:
#     0/1 flag. If set, access is permitted.
#
sub checkAuth {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    my $config = $self->config->section('creator_web_auth') || {};
    return (exists($config->{$user}) and crypt($pass, $config->{$user}) eq $config->{$user}) ? 1 : 0;
}

###############################################################################
# Check if given user is allowed to create specified jobs.
#
# Arguments:
#     user - string user login.
#     jobs - array of hashes with jobs that this user wishes to create.
# Returns:
#     0/1 flag. If set, access is permitted.
#
sub checkJobsAccess {
    my $self = shift;
    my $user = shift;
    my $jobs = shift;

    foreach my $job (@$jobs) {
        unless ($self->checkJobAccess($user, $job)) {
            return 0;
        }
    }

    return 1;
}

###############################################################################
# Check if given user is allowed to perform specific delay operation with specified jobs.
#
# Arguments:
#     user  - string user login.
#     delay - hash with delay data.
#     jobs  - array of hashes with jobs that this user wishes to delay.
# Returns:
#     0/1 flag. If set, access is permitted.
#
sub checkJobsDelayAccess {
    my $self = shift;
    my $user = shift;
    my $delay = shift;
    my $jobs = shift;

    foreach my $job (@$jobs) {
        unless ($self->checkJobDelayAccess($user, $delay, $job)) {
            return 0;
        }
    }

    return 1;
}

###############################################################################
# Check if given user is allowed to have individual private observer.
#
# Arguments:
#     user - string user login.
# Returns:
#     0/1 flag. If set, individual observer is provided.
#
sub hasIndividualObserver {
    my $self = shift;
    my $user = shift;
    return $self->getUserAccess($user)->hasAccess('iobserver');
}

###############################################################################
# Get template for rendering private event data by angularjs.
#
# Returns:
#     string template body.
#
sub getEventTemplate {
    my $self = shift;

    unless (exists($self->{eventTemplate})) {
        my $config = $self->config->getCreatorConfig('web') || {};
        my $eventTemplate = $config->{event_template} || 'event';
        $self->{eventTemplate} = getFileContent(File::Spec->catdir($self->config->getTemplatesPath(),
            'observers/app/web/' . $eventTemplate . '.html'));
    }

    return $self->{eventTemplate};
}

###############################################################################
# Execute preprocessing of jobs received from browser application.
# After that jobs array can be fed to creator 'createJobs' method.
#
# Arguments:
#     jobs - array of hashes with job data.
#
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

###############################################################################
# Execute preprocessing of job parameters received from browser application.
# Unbless any boolean values here to 0/1 scalars.
#
# Arguments:
#     params - hash with parameters.
#
sub preprocessJobParams {
    my $self = shift;
    my $params = shift;

    while (my ($name, $value) = each(%$params)) {
        if (ref($value) ne '' and reftype($value) eq 'SCALAR') {
            $params->{$name} = $$value;
        }
    }
}

###############################################################################
# Start observing private events for provided user connected to application via websocket connection.
#
# Arguments:
#     conn - websocket connection object which is capable to send data to client via 'send' method with automatic
#            serializing to JSON.
#     user - string user name.
#
sub observePrivateEvents {
    my $self = shift;
    my $conn = shift;
    my $user = shift;

    $self->stopObservePrivateEvents($user);
    $self->{connsByUser}->{$user} = $conn;

    if ($self->hasIndividualObserver($user)) {
        my $name = 'u' . $user;
        $self->{observersByUser}->{$user} = AnyJob::Creator::Observer->new(
            parent        => $self->parent,
            names         => [ $name ],
            addonsByNames => { $name => $self }
        );
        $self->{observersByUser}->{$user}->observe();
    }

    weaken($self);
    $conn->on(close => sub {
        if (defined($self) and exists($self->{connsByUser}->{$user}) and
            refaddr($conn) == refaddr($self->{connsByUser}->{$user})
        ) {
            $self->parent->setBusy(1);
            $self->stopObservePrivateEvents($user);
            $self->parent->setBusy(0);
        }
    });
}

###############################################################################
# Stop observing private events for provided user and remove all information about him from internal structures.
#
# Arguments:
#     user - string user name.
#
sub stopObservePrivateEvents {
    my $self = shift;
    my $user = shift;

    if (exists($self->{connsByUser}->{$user})) {
        $self->{connsByUser}->{$user}->close();
        delete $self->{connsByUser}->{$user};
    }

    if (exists($self->{observersByUser}->{$user})) {
        $self->{observersByUser}->{$user}->stop();
        delete $self->{observersByUser}->{$user};
    }
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
    if ($self->eventFilter($event) and defined(my $user = $event->{props}->{author})) {
        if (exists($self->{connsByUser}->{$user})) {
            $self->preprocessEvent($event);
            $self->{connsByUser}->{$user}->send($event);
        }
    }
    $self->parent->setBusy(0);
}

###############################################################################
# Prepare private observer event for further processing. Preprocess delayed works here if any.
#
# Arguments:
#     event - hash with event data.
#
sub preprocessEvent {
    my $self = shift;
    my $event = shift;

    $self->preprocessDelayedWorks($event);
}

###############################################################################
# Method called before shutdown and used to stop observing private events.
#
sub stop {
    my $self = shift;

    foreach my $user (keys(%{$self->{connsByUser}})) {
        $self->stopObservePrivateEvents($user);
    }
}

1;
