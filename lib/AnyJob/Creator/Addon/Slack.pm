package AnyJob::Creator::Addon::Slack;

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;

use base 'AnyJob::Creator::Addon::Base';

sub checkToken {
    my $self = shift;
    my $token = shift;

    my $config = $self->config->section('slack') || {};
    if (defined($config->{token}) and defined($token) and $config->{token} eq $token) {
        return 1;
    }

    return undef;
}

sub isUserAllowed {
    my $self = shift;
    my $user = shift;

    my $users;

    if (exists($self->{users})) {
        $users = $self->{users};
    } else {
        my $config = $self->config->section('slack') || {};
        if (defined($config->{users})) {
            $users = { map {$_ => 1} split(/\s*,\s*/, $config->{users}) };
        }
        $self->{users} = $users;
    }

    if (defined($users) and defined($user) and exists($users->{$user})) {
        return 1;
    }

    return undef;
}

sub getJobDialog {
    my $self = shift;
    my $job = shift;
    my $triggerId = shift;

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        return undef;
    }

    my $dialog = {
        callback_id  => $triggerId,
        title        => 'Create job \'' . ($config->{label} || $job->{type}) . '\'',
        submit_label => 'Create',
        elements     => [
            {
                type  => 'text',
                name  => 'nodes',
                label => 'Nodes',
                value => join('', grep {$self->config->isJobSupported($job->{type}, $_)} @{$job->{nodes}})
            }
        ]
    };

    my $params = $self->config->getJobParams($job->{type});
    foreach my $param (@$params) {
        if (defined(my $element = $self->getParamForDialog($param, $job->{params}))) {
            push @{$dialog->{elements}}, $element;
        }
    }

    my $props = $self->config->getProps();
    foreach my $prop (@$props) {
        if (defined(my $element = $self->getParamForDialog($prop, $job->{props}))) {
            push @{$dialog->{elements}}, $element;
        }
    }

    return $dialog;
}

sub getParamForDialog {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    if ($param->{type} eq "flag") {
        return {
            type     => 'select',
            name     => $param->{name},
            label    => $param->{label},
            value    => $values->{$param->{name}} ? 1 : 0,
            optional => $param->{required} ? 0 : 1,
            options  => [
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
    } elsif ($param->{type} eq 'text') {
        my $value = $values->{$param->{name}};
        return {
            type     => 'text',
            name     => $param->{name},
            label    => $param->{label},
            (defined($value) ? (value => $value) : ()),
            optional => $param->{required} ? 0 : 1,
        };
    } elsif ($param->{type} eq 'textarea') {
        my $value = $values->{$param->{name}};
        return {
            type     => 'textarea',
            name     => $param->{name},
            label    => $param->{label},
            (defined($value) ? (value => $value) : ()),
            optional => $param->{required} ? 0 : 1,
        };
    } elsif ($param->{type} eq 'combo') {
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

    return undef;
}

sub sendDialog {
    my $self = shift;
    my $dialog = shift;

    return $self->sendCommand('dialog.open', {
            trigger_id => $dialog->{callback_id},
            dialog     => $dialog
        });
}

sub sendCommand {
    my $self = shift;
    my $command = shift;
    my $data = shift;

    my $config = $self->config->section('slack') || {};
    unless (defined($config->{api}) and defined($config->{token})) {
        require Carp;
        Carp::confess('No api URL or token for slack');
    }

    my $request = POST(
        $config->{api} . $command,
        Content_Type  => 'application/json',
        Authorization => 'Bearer ' . $config->{token},
        Content       => encode_json($data)
    );

    my $result = $self->ua->request($request);
    unless ($result->is_success) {
        $self->error('Slack command failed, url: ' . $config->{api} . $command . ', response: ' . $result->content);
        return undef;
    } else {
        my $response;
        eval {
            $response = decode_json($result->content);
        };
        if ($@ or not $response->{ok}) {
            $self->error('Slack command failed, url: ' . $config->{api} . $command . ', response: ' . $result->content);
            return undef;
        }
    }

    return 1;
}

sub ua {
    my $self = shift;
    if (exists($self->{ua})) {
        return $self->{ua};
    }

    $self->{ua} = LWP::UserAgent->new();
    return $self->{ua};
}

1;
