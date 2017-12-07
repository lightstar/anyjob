package AnyJob::Creator::Addon::Web;

###############################################################################
# Addon that helps creating jobs and observing them using web application running in browser.
#
# Author:       LightStar
# Created:      21.11.2017
# Last update:  07.12.2017
#

use strict;
use warnings;
use utf8;

use File::Spec;
use Scalar::Util qw(reftype);
use AnyEvent;

use AnyJob::Constants::Defaults qw(DEFAULT_DELAY);
use AnyJob::Utils qw(getFileContent);

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
# Get template for rendering private event data by angularjs.
#
# Returns:
#     string template body.
#
sub getEventTemplate {
    my $self = shift;

    unless (exists($self->{appEventTemplate})) {
        $self->{appEventTemplate} = getFileContent(File::Spec->catdir($self->config->getTemplatesPath(),
            'observers/app/web/event.html'));
    }

    return $self->{appEventTemplate};
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
# Execute observing of private events for provided user connected to application via websocket connection.
# Observing is done via AnyEvent's timer run with configured interval.
#
# Arguments:
#     conn - websocket connection object. Only its method 'send' with array of event data hashes is used.
#            It is assumed that this connection will serialize this array by itself.
#     user - string user name which is used for observer queue name generation.
#
sub observePrivateEvents {
    my $self = shift;
    my $conn = shift;
    my $user = shift;

    my $config = $self->config->section('creator_web') || {};
    my $delay = $config->{observe_delay} || DEFAULT_DELAY;
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
