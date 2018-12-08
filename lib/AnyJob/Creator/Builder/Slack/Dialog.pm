package AnyJob::Creator::Builder::Slack::Dialog;

###############################################################################
# Slack builder used to create job using dialog shown on slash command.
# See https://api.slack.com/dialogs for details.
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  08.12.2018
#

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Creator::Builder::Slack::Base';

###############################################################################
# Handle slack slash command. Text is parsed by AnyJob::Creator::Parser module so look there for details.
# If parsing returns no unrecoverable errors, result is saved in build object and dialog is shown
# so user can clarify job parameters.
#
# Arguments:
#     text        - string command text.
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
# Returns:
#     string result to show user or undef.
#
sub command {
    my $self = shift;
    my $text = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;

    my ($delay, $job, $errors);
    ($delay, $job, undef, $errors) = $self->parent->parse($text, undef, { no_delay => 1 });
    unless (defined($job)) {
        return 'Error: ' . (scalar(@$errors) > 0 ? $errors->[0]->{text} : 'unknown error');
    }

    unless ($self->parentAddon->checkJobAccess($userId, $job)) {
        return 'Error: access denied';
    }

    $errors = [ grep {$_->{type} eq 'error' and $_->{text} !~ /no required param/} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    my $id = $self->getNextBuildId();
    $self->redis->zadd('anyjob:builds', time() + $self->getCleanTimeout(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json({
        type        => 'slack_dialog',
        userId      => $userId,
        userName    => $userName,
        job         => $job,
        (defined($delay) ? (delay => $delay) : ()),
        trigger     => $triggerId,
        responseUrl => $responseUrl
    }));

    $self->debug('Create slack app dialog build \'' . $id . '\' by user \'' . $userId . '\' (\'' . $userName .
        '\') with response url \'' . $responseUrl . '\', trigger \'' . $triggerId . '\' and job: ' . encode_json($job));

    $self->showDialog($triggerId, $self->getDialog($job, $id));

    return undef;
}

###############################################################################
# Handle dialog submission. Finish build and create job here if there are no errors.
#
# Arguments:
#     payload - hash data with dialog submission.
# Returns:
#     hash data with response payload, string result to show user or undef.
#
sub dialogSubmission {
    my $self = shift;
    my $payload = shift;

    my ($id, $build);
    (undef, $id) = split(/:/, $payload->{callback_id});
    unless (defined($id) and defined($build = $self->getBuild($id))) {
        return 'Error: no build';
    }

    unless (defined($payload->{user}) and
        $payload->{user}->{id} eq $build->{userId} and
        $payload->{user}->{name} eq $build->{userName}
    ) {
        return 'Error: access denied';
    }

    my $errors = $self->applySubmission($build->{job}, $payload->{submission});
    if (scalar(@$errors) > 0) {
        return {
            errors => $errors
        };
    }

    $self->cleanBuild($id);

    $self->debug('Create jobs using slack app dialog build: ' . encode_json($build));

    my $error = $self->parent->createJobs([ $build->{job} ], {
        creator      => 'slack',
        author       => $build->{userName},
        observer     => 'slack',
        response_url => $build->{responseUrl}
    });
    if (defined($error)) {
        $self->debug('Creating failed: ' . $error);
        $self->sendResponse({ text => 'Error: ' . $error }, $build->{responseUrl});
    } else {
        $self->sendResponse({ text => 'Job created' }, $build->{responseUrl});
    }

    return undef;
}

###############################################################################
# Inject dialog submission data into provided job data saved previously.
# Look for errors and missed required parameters.
#
# Arguments:
#     job        - hash with job data.
#     submission - hash with dialog submission data.
# Returns:
#     array of hashes with error data as described by slack dialog api.
#
sub applySubmission {
    my $self = shift;
    my $job = shift;
    my $submission = shift;

    my $params = $self->config->getJobParams($job->{type});
    my @errors;
    foreach my $param (@$params) {
        if (defined($submission->{$param->{name}})) {
            unless ($self->parent->checkJobParamType($param->{type}, $submission->{$param->{name}},
                $param->{options})) {
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

###############################################################################
# Construct dialog payload which can be shown to slack user.
#
# Arguments:
#     job - hash with job data.
#     id  - integer build id (needed to generate callback_id).
# Returns:
#     hash with dialog data as described by slack dialog api.
#
sub getDialog {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my $config = $self->config->getJobConfig($job->{type}) || {};
    my $dialog = {
        callback_id  => $self->name . ':' . $id,
        title        => substr('Create job \'' . ($config->{label} || $job->{type}) . '\'', 0, 24),
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

###############################################################################
# Construct dialog element for one specific parameter.
#
# Arguments:
#     param  - hash with job parameter info from configuration.
#     values - hash with parameters from job data.
# Returns:
#     hash with dialog element data or undef if parameter type is unknown.
#
sub getParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    if ($param->{type} eq 'flag') {
        return $self->getFlagParamElement($param, $values);
    } elsif ($param->{type} eq 'text' or $param->{type} eq 'datetime') {
        return $self->getTextParamElement($param, $values);
    } elsif ($param->{type} eq 'textarea') {
        return $self->getTextAreaParamElement($param, $values);
    } elsif ($param->{type} eq 'combo') {
        return $self->getComboParamElement($param, $values);
    }

    return undef;
}

###############################################################################
# Construct dialog element for parameter with 'flag' type.
#
# Arguments:
#     param  - hash with job parameter info from configuration.
#     values - hash with parameters from job data.
# Returns:
#     hash with dialog element data.
#
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

###############################################################################
# Construct dialog element for parameter with 'text' type.
#
# Arguments:
#     param  - hash with job parameter info from configuration.
#     values - hash with parameters from job data.
# Returns:
#     hash with dialog element data.
#
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

###############################################################################
# Construct dialog element for parameter with 'textarea' type.
#
# Arguments:
#     param  - hash with job parameter info from configuration.
#     values - hash with parameters from job data.
# Returns:
#     hash with dialog element data.
#
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

###############################################################################
# Construct dialog element for parameter with 'combo' type.
#
# Arguments:
#     param  - hash with job parameter info from configuration.
#     values - hash with parameters from job data.
# Returns:
#     hash with dialog element data.
#
sub getComboParamElement {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    my $value = $values->{$param->{name}};
    unless (defined($value) and grep {$_->{value} eq $value} @{$param->{options}}) {
        $value = undef;
    }

    return {
        type     => 'select',
        name     => $param->{name},
        label    => $param->{label},
        (defined($value) ? (value => $value) : ()),
        optional => $param->{required} ? 0 : 1,
        options  => [ map {{ label => $_->{label}, value => $_->{value} }} @{$param->{options}} ]
    };
}

1;
