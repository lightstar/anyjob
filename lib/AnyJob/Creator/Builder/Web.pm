package AnyJob::Creator::Builder::Web;

###############################################################################
# Builder used by web creator to perform multi-step operations.
#
# Author:       LightStar
# Created:      15.01.2019
# Last update:  16.01.2019
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_STATUS EVENT_GET_DELAYED_WORKS);
use AnyJob::Constants::Delay qw(DELAY_ACTION_UPDATE DELAY_ACTION_DELETE);

use base 'AnyJob::Creator::Builder::Base';

###############################################################################
# Construct new AnyJob::Creator::Builder::Web object.
#
# Arguments:
#     parent - parent component which is usually AnyJob::Creator object.
# Returns:
#     AnyJob::Creator::Builder::Web object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{name} = 'web';
    my $self = $class->SUPER::new(%args);
    return $self;
}

###############################################################################
# Returns:
#     parent component's web addon object.
#
sub parentAddon {
    my $self = shift;
    return $self->{parent}->addon('web');
}

###############################################################################
# Get builder configuration or undef.
#
# Returns:
#     hash with builder configuration or undef if there are no such builder in config.
#
sub getBuilderConfig {
    my $self = shift;
    return $self->config->getBuilderConfig('web');
}

###############################################################################
# Method which will be called when new service event arrives.
#
# Arguments:
#     event - hash with event data.
#
sub receiveServiceEvent {
    my $self = shift;
    my $event = shift;

    if ($event->{event} eq EVENT_GET_DELAYED_WORKS) {
        $self->continueDelayedWorkAction($event);
    }
}

###############################################################################
# Start multi-step delayed work action ('update' or 'delete'). Special build is created here and service command
# 'get delayed works' is initiated to get delayed work user wishes to update or delete.
# Later on builder will receive service event 'get delayed works' and process it to continue operation.
#
# Arguments:
#     delay       - hash with delay data.
#     jobs        - array of hashes with jobs data or undef.
#     user        - string user name.
#     observer    - string user observer.
#     updateCount - integer update count of processing delayed work. It will be checked for permanency.
#
sub startDelayedWorkAction {
    my $self = shift;
    my $delay = shift;
    my $jobs = shift;
    my $user = shift;
    my $observer = shift;
    my $updateCount = shift;

    $self->debug('Start delayed work action using web app build by user \'' . $user .
        '\' with update count: ' . $updateCount . (defined($jobs) ? ', jobs: ' . encode_json($jobs) : '') .
        ' and delay: ' . encode_json($delay));

    my $params = {
        jobs        => $jobs,
        delay       => $delay,
        user        => $user,
        observer    => $observer,
        updateCount => $updateCount
    };

    my $id = $self->getNextBuildId();
    $self->redis->zadd('anyjob:builds', time() + $self->getCleanTimeout(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json($params));

    $self->parent->getDelayedWorks($observer, $delay->{id}, {
        service => $id
    });
}

###############################################################################
# Continue update or delete delayed work operation.
#
# Arguments:
#     event - hash with event data.
#
sub continueDelayedWorkAction {
    my $self = shift;
    my $event = shift;

    my $id = $event->{props}->{service};
    my $build = $self->getBuild($id);
    unless (defined($build)) {
        return;
    }

    $self->debug('Continue delayed work action using web app build by user \'' .
        $build->{user} . '\' with update count: ' . $build->{updateCount} .
        (defined($build->{jobs}) ? ', jobs: ' . encode_json($build->{jobs}) : '') .
        ', delay: ' . encode_json($build->{delay}) . ' and event: ' . encode_json($event));

    my $error = undef;
    if (scalar(@{$event->{works}}) != 1) {
        $error = 'delayed work not found';
    } else {
        my $action = $build->{delay}->{action};
        my $work = $event->{works}->[0];

        if ($work->{update} != $build->{updateCount}) {
            $error = 'delayed work had changed';
        } elsif (not $self->parentAddon->checkDelayedWorkAccess($build->{user}, $action, $work)) {
            $error = 'access denied';
        } elsif ($action eq DELAY_ACTION_UPDATE) {
            $error = $self->updateDelayedWork($build->{delay}, $build->{jobs}, $build->{user}, $build->{observer},
                $work->{update});
        } elsif ($action eq DELAY_ACTION_DELETE) {
            $error = $self->deleteDelayedWork($build->{delay}, $build->{user}, $build->{observer}, $work->{update});
        }
    }

    $self->cleanBuild($id);

    if (defined($error)) {
        $self->debug('Delayed work action failed: ' . $error);
        $self->parentAddon->directEvent({
            event   => EVENT_STATUS,
            success => 0,
            message => $error,
            props   => {
                creator  => 'web',
                author   => $build->{user},
                observer => $build->{observer}
            }
        });
    }
}

###############################################################################
# Update delayed work.
#
# Arguments:
#     delay       - hash with delay data.
#     jobs        - array of hashes with jobs data.
#     user        - string user name.
#     observer    - string user observer.
#     updateCount - integer update count of processing delayed work. It will be checked for permanency.
# Returns:
#     reply string with error message or undef if there are no errors. Final operation result will be received via
#     status event from delay controller.
#
sub updateDelayedWork {
    my $self = shift;
    my $delay = shift;
    my $jobs = shift;
    my $user = shift;
    my $observer = shift;
    my $updateCount = shift;

    $self->debug('Update delayed work using web app build by user \'' . $user . '\'' . ' with update count: ' .
        $updateCount . ', jobs: ' . encode_json($jobs) . ' and delay: ' . encode_json($delay));

    my $error = $self->parent->delayJobs($delay, $jobs, {
        creator  => 'web',
        author   => $user,
        observer => $observer
    }, {
        check_update   => $updateCount,
        status_service => 'web'
    });

    if (defined($error)) {
        $self->debug('Updating failed: ' . $error);
        return $error;
    }

    return undef;
}

###############################################################################
# Delete delayed work.
#
# Arguments:
#     delay       - hash with delay data.
#     user        - string user name.
#     observer    - string user observer.
#     updateCount - integer update count of processing delayed work. It will be checked for permanency.
# Returns:
#     reply string with error message or undef if there are no errors. Final operation result will be received via
#     status event from delay controller.
#
sub deleteDelayedWork {
    my $self = shift;
    my $delay = shift;
    my $user = shift;
    my $observer = shift;
    my $updateCount = shift;

    $self->debug('Delete delayed work using web app build by user \'' . $user . '\'' . ' with update count: ' .
        $updateCount . ' and delay: ' . encode_json($delay));

    $self->parent->deleteDelayedWork($delay->{id}, {
        creator  => 'web',
        author   => $user,
        observer => $observer,
    }, {
        check_update   => $updateCount,
        status_service => 'web'
    });

    return undef;
}

1;
