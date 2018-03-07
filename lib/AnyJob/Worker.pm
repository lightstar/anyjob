package AnyJob::Worker;

###############################################################################
# Worker component subclassed from AnyJob::Base, which primary task is to directly execute jobs.
# Job logic is implemented by one of specific worker modules
# (usually with 'AnyJob::Worker::Job' prefix but that's not strictly required).
# Also long-term context object can be used to share any resources.
#
# Author:       LightStar
# Created:      17.10.2017
# Last update:  07.03.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Defaults qw(
    DEFAULT_WORKER_PREFIX DEFAULT_WORKER_CONTEXT_PREFIX DEFAULT_WORKER_METHOD
);
use AnyJob::Constants::States qw(STATE_BEGIN STATE_RUN);
use AnyJob::Utils qw(getModuleName requireModule);

use base 'AnyJob::Base';

###############################################################################
# Construct new AnyJob::Worker object.
#
# Arguments:
#     name - optional string with worker name.
# Returns:
#     AnyJob::Worker object.
#
sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = 'worker';
    my $self = $class->SUPER::new(%args);
    $self->initContext();
    return $self;
}

###############################################################################
# Returns:
#     string worker name or undef if worker hasn't name.
#
sub name {
    my $self = shift;
    return $self->{name};
}

###############################################################################
# Get worker configuration or undef.
#
# Returns:
#     hash with worker configuration or undef if worker hasn't name or there are no such worker in config.
#
sub getWorkerConfig {
    my $self = shift;
    return defined($self->{name}) ? $self->config->getWorkerConfig($self->{name}) : undef;
}

###############################################################################
# Init worker context object if configured to.
#
sub initContext {
    my $self = shift;

    my $config = $self->getWorkerConfig() || {};
    my $workerSection = $self->config->section('worker') || {};
    my $module = $config->{context_module} || $workerSection->{context_module};
    unless (defined($module)) {
        $self->{context} = undef;
        return;
    }

    my $prefix = $config->{context_prefix} || $workerSection->{context_prefix} || DEFAULT_WORKER_CONTEXT_PREFIX;
    $module = $prefix . '::' . getModuleName($module);

    requireModule($module);
    $self->{context} = $module->new(parent => $self);
}

###############################################################################
# Returns:
#     context object which is usually subclass of AnyJob::Worker::Context::Base class or undef if no context configured.
#
sub context {
    my $self = shift;
    return $self->{context};
}

###############################################################################
# Send message to daemon's progress queue.
#
# Arguments:
#     id       - integer job id.
#     progress - string progress value or hash with arbitrary message data.
#     data     - optional hash with progress data.
#
sub sendProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;
    my $data = shift;

    unless (ref($progress) eq 'HASH') {
        $progress = {
            progress => $progress,
            (defined($data) ? (data => $data) : ())
        };
    } elsif (defined($data)) {
        $progress->{data} = $data;
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
#     data  - optional hash with progress data.
#
sub sendState {
    my $self = shift;
    my $id = shift;
    my $state = shift;
    my $data = shift;

    $self->sendProgress($id, {
        state => $state,
        (defined($data) ? (data => $data) : ())
    })
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
#     id      - integer job id.
#     message - string log message.
#     level   - optional integer log level (default: 0).
#     tag     - optional string tag (default: '').
#     data    - optional hash with progress data.
#
sub sendLog {
    my $self = shift;
    my $id = shift;
    my $message = shift;
    my $level = shift;
    my $tag = shift;
    my $data = shift;

    if (defined($level) and $level !~ /^\d+$/o) {
        $level = 0;
    }

    $self->sendProgress($id, {
        log => {
            time    => time(),
            message => $message,
            (defined($level) ? (level => $level) : ()),
            (defined($tag) ? (tag => $tag) : ())
        },
        (defined($data) ? (data => $data) : ())
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
#     data    - optional hash with result data.
#
sub sendSuccess {
    my $self = shift;
    my $id = shift;
    my $message = shift;
    my $data = shift;

    $self->sendProgress($id, {
        success => 1,
        message => $message,
        (defined($data) ? (data => $data) : ())
    });
}

###############################################################################
# Send message to daemon's progress queue finishing job with error.
#
# Arguments:
#     id      - integer job id.
#     message - string finish message.
#     data    - optional hash with result data.
#
sub sendFailure {
    my $self = shift;
    my $id = shift;
    my $message = shift;
    my $data = shift;

    $self->sendProgress($id, {
        success => 0,
        message => $message,
        (defined($data) ? (data => $data) : ())
    });
}

###############################################################################
# Send message to daemon's jobset progress queue.
#
# Arguments:
#     id       - integer jobset id.
#     progress - string progress value or hash with arbitrary message data.
#     data     - optional hash with progress data.
#
sub sendJobSetProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;
    my $data = shift;

    unless (ref($progress) eq 'HASH') {
        $progress = {
            progress => $progress,
            (defined($data) ? (data => $data) : ())
        };
    } elsif (defined($data)) {
        $progress->{data} = $data;
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
#     data  - optional hash with progress data.
#
sub sendJobSetState {
    my $self = shift;
    my $id = shift;
    my $state = shift;
    my $data = shift;

    $self->sendJobSetProgress($id, {
        state => $state,
        (defined($data) ? (data => $data) : ())
    })
}

###############################################################################
# Send redo message to daemon's progress queue which will lead to running this job again.
#
# Arguments:
#     id - integer job id.
#
sub sendRedo {
    my $self = shift;
    my $id = shift;

    $self->sendProgress($id, { redo => 1 });
}

###############################################################################
# Execute job with given id and then clean all resources.
#
# Arguments:
#     id - integer job id.
#
sub runJobAndStop {
    my $self = shift;
    my $id = shift;

    $self->runJob($id);
    $self->stop();
}

###############################################################################
# Execute job with given id calling configured module to do its logic.
# To simplify job modules developing that call is wrapped around different checks,
# logging and auto-changing to 'run' state.
#
# Arguments:
#     id - integer job id.
#
sub runJob {
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

    my $workerConfig = $self->getWorkerConfig() || {};
    my $workerSection = $self->config->section('worker') || {};

    my $module = getModuleName($jobConfig->{module} || $workerConfig->{module} || $workerSection->{module} ||
        $job->{type});
    my $prefix = $jobConfig->{prefix} || $workerConfig->{prefix} || $workerSection->{prefix} || DEFAULT_WORKER_PREFIX;
    $module = $prefix . '::' . $module;

    eval {
        requireModule($module);
    };
    if ($@) {
        $self->error('Error loading module \'' . $module . '\': ' . $@);
        return;
    }

    $self->debug('Execute job \'' . $id . '\' on node \'' . $self->node . '\': ' . encode_json($job));

    if ($job->{state} eq STATE_BEGIN) {
        $self->sendRun($id);
    }

    my $method = $jobConfig->{method} || $workerConfig->{method} || $workerSection->{method} || DEFAULT_WORKER_METHOD;
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

###############################################################################
# Must be called after finishing all processing. Clean all resources here.
#
sub stop() {
    my $self = shift;

    if (defined($self->{context})) {
        $self->{context}->stop();
    }
}

1;
