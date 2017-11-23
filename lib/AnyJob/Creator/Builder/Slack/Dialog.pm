package AnyJob::Creator::Builder::Slack::Dialog;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Base';

sub build {
    my $self = shift;
    my $text = shift;
    my $user = shift;
    my $responseUrl = shift;
    my $trigger = shift;

    my ($job, $extra, $errors) = $self->parent->parseJobLine($text);
    unless (defined($job)) {
        return {
            text => 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{error} : 'unknown error')
        };
    }

    my $id = $self->nextBuildId();
    $self->redis->zadd('anyjob:builds', time(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json({
            type        => 'slack_dialog',
            user        => $user,
            job         => $job,
            trigger     => $trigger,
            responseUrl => $responseUrl
        }));

    $self->debug('Create slack app dialog build \'' . $id . '\' by user \'' . $user . '\' with response url \'' .
        $responseUrl . '\', trigger \'' . $trigger . '\' and job: ' . encode_json($job));

    my $dialog = $self->getDialog($job, $id);
    unless (defined($dialog)) {
        $self->cleanBuild($id);
        return {
            text => 'Error: unknown error'
        };
    }

    unless (defined($self->sendDialog($trigger, $dialog))) {
        $self->cleanBuild($id);
        return {
            text => 'Error: failed to open dialog'
        };
    }

    return undef;
}

sub update {
    my $self = shift;
    my $payload = shift;

    if ($payload->{type} ne 'dialog_submission') {
        return {
            text => 'Error: not dialog submission type'
        };
    }

    my ($name, $id) = split(/:/, $payload->{callback_id});
    unless (defined($id)) {
        return {
            text => 'Error: no build'
        };
    }

    my $build = $self->getBuild($id);
    unless (defined($build)) {
        return {
            text => 'Error: no build'
        };
    }

    my $errors = $self->applyDialogSubmission($build->{job}, $payload->{submission});
    if (scalar(@$errors) > 0) {
        return {
            errors => $errors
        };
    }

    $self->cleanBuild($id);
    $self->finish($build);
    return undef;
}

sub applyDialogSubmission {
    my $self = shift;
    my $job = shift;
    my $submission = shift;

    my $params = $self->config->getJobParams($job->{type});
    my @errors;
    foreach my $param (@$params) {
        if (exists($submission->{$param->{name}})) {
            unless ($self->parent->checkParamType($param->{type}, $submission->{$param->{name}}, $param->{data})) {
                push @errors, {
                        name  => $param->{name},
                        error => 'wrong param'
                    };
            } else {
                $job->{params}->{$param->{name}} = $submission->{$param->{name}};
            }
        }

        if ($param->{required} and
            (not defined($submission->{$param->{name}}) or $submission->{$param->{name}} eq '')
        ) {
            push @errors, {
                    name  => $param->{name},
                    error => 'param is required'
                };
        }
    }

    return \@errors;
}

sub finish {
    my $self = shift;
    my $build = shift;

    $self->debug('Create jobs using slack app dialog build: ' . encode_json($build));

    my $error = $self->parent->createJobs([ $build->{job} ], 'su' . $build->{user}, $build->{responseUrl});
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        $self->sendResponse({ text => 'Error: ' . $error }, $build->{responseUrl});
    } else {
        $self->sendResponse({ text => 'Job created' }, $build->{responseUrl});
    }

    return undef;
}

sub getDialog {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        $self->error('No config for job with type \'' . $job->{type} . '\'');
        return undef;
    }

    my $dialog = {
        callback_id  => $self->name . ':' . $id,
        title        => 'Create job \'' . ($config->{label} || $job->{type}) . '\'',
        submit_label => 'Create',
        elements     => []
    };

    my $params = $self->config->getJobParams($job->{type});
    foreach my $param (@$params) {
        if (defined(my $element = $self->getParamElement($param, $job->{params}))) {
            push @{$dialog->{elements}}, $element;
        }
    }

    return $dialog;
}

sub getParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    if ($param->{type} eq 'flag') {
        return $self->getFlagParamElement($param, $values);
    } elsif ($param->{type} eq 'text') {
        return $self->getTextParamElement($param, $values);
    } elsif ($param->{type} eq 'textarea') {
        return $self->getTextAreaParamElement($param, $values);
    } elsif ($param->{type} eq 'combo') {
        return $self->getComboParamElement($param, $values);
    }

    return undef;
}

sub getFlagParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    return {
        type    => 'select',
        name    => $param->{name},
        label   => $param->{label},
        value   => $values->{$param->{name}} ? 1 : 0,
        options => [
            {
                label => 'Yes',
                value => 1
            },
            {
                label => 'No',
                value => 0
            }
        ]
    };
}

sub getTextParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    my $value = $values->{$param->{name}};

    return {
        type     => 'text',
        name     => $param->{name},
        label    => $param->{label},
        (defined($value) ? (value => $value) : ()),
        optional => $param->{required} ? 0 : 1,
    };
}

sub getTextAreaParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    my $value = $values->{$param->{name}};

    return {
        type     => 'textarea',
        name     => $param->{name},
        label    => $param->{label},
        (defined($value) ? (value => $value) : ()),
        optional => $param->{required} ? 0 : 1,
    };
}

sub getComboParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    my $value = $values->{$param->{name}};
    unless (defined($value) and grep {$_->{value} eq $value} @{$param->{data}}) {
        $value = undef;
    }

    return {
        type     => 'select',
        name     => $param->{name},
        label    => $param->{label},
        (defined($value) ? (value => $value) : ()),
        optional => $param->{required} ? 0 : 1,
        options  => [ map {{ label => $_->{label}, value => $_->{value} }} @{$param->{data}} ]
    };
}

1;
