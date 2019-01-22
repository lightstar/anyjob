package AnyJob::Creator::Builder::Slack::Dialog;

###############################################################################
# Slack builder used to create job using dialog shown on slash command.
# See https://api.slack.com/dialogs for details.
#
# Author:       LightStar
# Created:      22.11.2017
# Last update:  22.01.2019
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
#     string result to show to user or undef.
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

    if (defined(my $parseErrors = $self->checkParseErrors($errors))) {
        return $parseErrors;
    }

    my ($dialog, $id, $error) = $self->createDialogAndBuild($userId, $responseUrl, $triggerId, $userName, $job);
    if (defined($error)) {
        return 'Error: ' . $error;
    }

    $self->debug('Create slack app dialog build \'' . $id . '\' by user \'' . $userId . '\' (\'' . $userName .
        '\') with response url \'' . $responseUrl . '\', trigger \'' . $triggerId . '\' and job: ' . encode_json($job));

    $self->showDialog($triggerId, $dialog);

    return undef;
}

###############################################################################
# Check errors returned by AnyJob::Creator::Parser module and return error string if they are unrecoverable.
#
# Arguments:
#     errors - array with parse errors.
# Returns:
#     string error to show to user or undef.
#
sub checkParseErrors {
    my $self = shift;
    my $errors = shift;

    $errors = [ grep {$_->{type} eq 'error' and $_->{text} !~ /no required param/} @$errors ];
    if (scalar(@$errors) > 0) {
        return 'Error' . (scalar(@$errors) > 1 ? 's' : '') . ': ' . join(', ', map {$_->{text}} @$errors);
    }

    return undef;
}

###############################################################################
# Action name to show in dialog.
#
# Returns:
#     string action name.
#
sub action {
    my $self = shift;
    return 'Create';
}

###############################################################################
# Handle dialog submission. Finish build and create job here if there are no errors.
#
# Arguments:
#     payload - hash data with dialog submission.
# Returns:
#     hash data with response payload, string result to show to user or undef.
#
sub dialogSubmission {
    my $self = shift;
    my $payload = shift;

    my ($build, $error) = $self->finishBuild($payload);
    if (defined($error)) {
        return ref($error) eq 'HASH' ? $error : 'Error: ' . $error;
    }

    $self->debug('Create jobs using slack app dialog build: ' . encode_json($build));

    $error = $self->parent->createJobs([ $build->{job} ], {
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
# Create dialog and related build object.
#
# Arguments:
#     userId      - string user id.
#     responseUrl - string response url.
#     triggerId   - string trigger id.
#     userName    - string user name.
#     job         - hash with parsed job data.
#     extraParams - optional hash with extra parameters which will be injected into build or undef.
# Returns:
#     integer build id or undef.
#     hash with dialog data as described by slack dialog api or undef.
#     string error or undef.
#
sub createDialogAndBuild {
    my $self = shift;
    my $userId = shift;
    my $responseUrl = shift;
    my $triggerId = shift;
    my $userName = shift;
    my $job = shift;
    my $extraParams = shift;

    my $params = {
        userId      => $userId,
        userName    => $userName,
        job         => $job,
        trigger     => $triggerId,
        responseUrl => $responseUrl
    };

    if (defined($extraParams)) {
        my @keys = keys(%$extraParams);
        @{$params}{@keys} = @{$extraParams}{@keys};
    }

    my $id = $self->getNextBuildId();
    $self->redis->zadd('anyjob:builds', time() + $self->getCleanTimeout(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json($params));

    my $dialog = $self->getDialog($job, $id);
    if (scalar(@{$dialog->{elements}}) == 0) {
        $self->cleanBuild($id);
        return +(undef, undef, 'job has no parameters to show in dialog');
    }

    return +($dialog, $id, undef);
}

###############################################################################
# Finish build injecting dialog data into it. If there are no errors, build is removed afterwards.
#
# Arguments:
#     payload - hash data with dialog submission.
# Returns:
#     hash with build data or undef.
#     string error or hash with errors or undef.
#
sub finishBuild {
    my $self = shift;
    my $payload = shift;

    my ($id, $build);
    (undef, $id) = split(/:/, $payload->{callback_id});
    unless (defined($id) and defined($build = $self->getBuild($id))) {
        return +(undef, 'no build');
    }

    unless (defined($payload->{user}) and
        $payload->{user}->{id} eq $build->{userId} and
        $payload->{user}->{name} eq $build->{userName}
    ) {
        return +(undef, 'access denied');
    }

    my $errors = $self->applySubmission($build->{job}, $payload->{submission});
    if (scalar(@$errors) > 0) {
        return +(undef, {
            errors => $errors
        });
    }

    $self->cleanBuild($id);

    return +($build, undef);
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

    my $action = $self->action();
    my $config = $self->config->getJobConfig($job->{type}) || {};
    my $dialog = {
        callback_id  => $self->name . ':' . $id,
        title        => substr($action . ' job \'' . ($config->{label} || $job->{type}) . '\'', 0, 24),
        submit_label => $action,
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
