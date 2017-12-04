package AnyJob::Worker;

###############################################################################
# Worker component subclassed from AnyJob::Base, which primary task is to directly execute jobs.
# Job logic is implemented by one of specific worker modules
# (usually under 'Worker' package path but that's not strictly required).
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  04.12.2017
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::States qw(STATE_RUN);
use AnyJob::Utils qw(getModuleName requireModule);

use base 'AnyJob::Base';

###############################################################################
# Construct new AnyJob::Worker object.
#
# Returns:
#     AnyJob::Worker object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'worker';
    my $self = $class->SUPER::new(%args);
    return $self;
}

###############################################################################
# Send message to daemon's progress queue.
#
# Arguments:
#     id       - integer job id.
#     progress - string progress value or hash with arbitrary message data.
#
sub sendProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    unless (ref($progress) eq 'HASH') {
        $progress = { progress => $progress };
    }

    $progress->{id} = $id;
    $self->redis->rpush('anyjob:progressq:' . $self->node, encode_json($progress));
}

###############################################################################
# Send change state message to daemon's progress queue.
#
# Arguments:
#     id    - integer job id.
#     state - string state value.
#
sub sendState {
    my $self = shift;
    my $id = shift;
    my $state = shift;

    $self->sendProgress($id, { state => $state })
}

###############################################################################
# Send message to daemon's progress queue changing state to 'run'.
#
# Arguments:
#     id - integer job id.
#
sub sendRun {
    my $self = shift;
    my $id = shift;

    $self->sendState($id, STATE_RUN);
}

###############################################################################
# Send message to daemon's progress queue with some log message.
#
# Arguments:
#     id       - integer job id.
#     message  - string log message.
#
sub sendLog {
    my $self = shift;
    my $id = shift;
    my $message = shift;

    $self->sendProgress($id, {
            log => {
                time    => time(),
                message => $message
            }
        });
}

###############################################################################
# Send message to daemon's progress queue redirecting job to given node.
#
# Arguments:
#     id   - integer job id.
#     node - string node name.
#
sub sendRedirect {
    my $self = shift;
    my $id = shift;
    my $node = shift;

    $self->sendProgress($id, { redirect => $node });
}

###############################################################################
# Send message to daemon's progress queue successfully finishing job.
#
# Arguments:
#     id      - integer job id.
#     message - string finish message.
#
sub sendSuccess {
    my $self = shift;
    my $id = shift;
    my $message = shift;

    $self->sendProgress($id, { success => 1, message => $message });
}

###############################################################################
# Send message to daemon's progress queue finishing job with error.
#
# Arguments:
#     id      - integer job id.
#     message - string finish message.
#
sub sendFailure {
    my $self = shift;
    my $id = shift;
    my $message = shift;

    $self->sendProgress($id, { success => 0, message => $message });
}

###############################################################################
# Send message to daemon's jobset progress queue.
#
# Arguments:
#     id       - integer jobset id.
#     progress - string progress value or hash with arbitrary message data.
#
sub sendJobSetProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    unless (ref($progress) eq 'HASH') {
        $progress = { progress => $progress };
    }

    $progress->{id} = $id;
    $self->redis->rpush('anyjob:progressq', encode_json($progress));
}

###############################################################################
# Send change state message to daemon's jobset progress queue.
#
# Arguments:
#     id    - integer jobset id.
#     state - string state value.
#
sub sendJobSetState {
    my $self = shift;
    my $id = shift;
    my $state = shift;

    $self->sendJobSetProgress($id, { state => $state })
}

###############################################################################
# Execute job with given id calling configured module to do its logic.
# To simplify job modules developing that call is wrapped around different checks,
# logging and auto-changing to 'run' state.
#
# Arguments:
#     id - integer job id.
#
sub run {
    my $self = shift;
    my $id = shift;

    if ($self->config->node eq '') {
        $self->error('No node');
        return;
    }

    my $job = $self->getJob($id);
    unless (defined($job)) {
        $self->error('Job \'' . $id . '\' not found');
        return;
    }

    my $jobConfig = $self->config->getJobConfig($job->{type});
    unless (defined($jobConfig)) {
        $self->error('No config for job type \'' . $job->{type} . '\'');
        return;
    }

    unless ($self->config->isJobSupported($job->{type})) {
        $self->error('Job with type \'' . $job->{type} . '\' is not supported on this node');
        return;
    }

    my $workerConfig = $self->config->section('worker') || {};

    my $module = getModuleName($jobConfig->{module} || $workerConfig->{module} || $job->{type});
    my $prefix = $jobConfig->{prefix} || $workerConfig->{prefix} || 'AnyJob::Worker';
    if (defined($prefix)) {
        $module = $prefix . '::' . $module;
    }
    requireModule($module);

    $self->debug('Execute job \'' . $id . '\' on node \'' . $self->node . '\': ' . encode_json($job));

    $self->sendRun($id);

    my $method = $jobConfig->{method} || $workerConfig->{method} || 'run';
    eval {
        no strict 'refs';
        $module->new(parent => $self, id => $id, job => $job)->$method();
    };
    if ($@) {
        $self->error('Error running method \'' . $method . '\' in module \'' . $module . '\': ' . $@);
        return;
    }

    $self->debug('Finish job \'' . $id . '\'');
}

1;
