package AnyJob::Worker;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Utils qw(moduleName);

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "worker";
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub sendProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    unless (ref($progress) eq "HASH") {
        $progress = { progress => $progress };
    }

    $progress->{id} = $id;
    $self->redis->rpush("anyjob:progressq:" . $self->node, encode_json($progress));
}

sub sendState {
    my $self = shift;
    my $id = shift;
    my $state = shift;

    $self->sendProgress($id, { state => $state })
}

sub sendRun {
    my $self = shift;
    my $id = shift;

    $self->sendState($id, "run");
}

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

sub sendRedirect {
    my $self = shift;
    my $id = shift;
    my $node = shift;

    $self->sendProgress($id, { redirect => $node });
}

sub sendSuccess {
    my $self = shift;
    my $id = shift;
    my $message = shift;

    $self->sendProgress($id, { success => 1, message => $message });
}

sub sendFailure {
    my $self = shift;
    my $id = shift;
    my $message = shift;

    $self->sendProgress($id, { success => 0, message => $message });
}

sub sendJobSetProgress {
    my $self = shift;
    my $id = shift;
    my $progress = shift;

    unless (ref($progress) eq "HASH") {
        $progress = { progress => $progress };
    }

    $progress->{id} = $id;
    $self->redis->rpush("anyjob:progressq", encode_json($progress));
}

sub sendJobSetState {
    my $self = shift;
    my $id = shift;
    my $state = shift;

    $self->sendJobSetProgress($id, { state => $state })
}

sub run {
    my $self = shift;
    my $id = shift;

    my $job = $self->getJob($id);
    unless (defined($job)) {
        $self->error("Job '" . $id . "' not found");
        return;
    }

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        $self->error("No config for job type '" . $job->{type} . "'");
        return;
    }

    my $workerSection = $self->config->section("worker") || {};

    my $module = moduleName($config->{module} || $workerSection->{module} || $job->{type});
    my $prefix = $config->{prefix} || $workerSection->{prefix} || "AnyJob::Worker";
    if (defined($prefix)) {
        $module = $prefix . "::" . $module;
    }

    eval "require $module";
    if ($@) {
        $self->error("Can't load module '" . $module . "': " . $@);
        return;
    }

    $self->debug("Perform job '" . $id . "' on node '" . $self->node . "': " . encode_json($job));

    $self->sendRun($id);

    my $method = $config->{method} || $workerSection->{method} || "run";
    eval {
        no strict 'refs';
        $module->new(worker => $self, id => $id, job => $job)->$method();
    };
    if ($@) {
        $self->error("Error running method '" . $method . "' in module '" . $module . "': " . $@);
        return;
    }

    $self->debug("Finish perform job '" . $id . "'");
}

1;
