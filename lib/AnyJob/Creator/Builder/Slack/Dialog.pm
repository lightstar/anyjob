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
    my $trigger_id = shift;

    my ($job, $extra, $errors) = $self->parent->parseJobLine($text);
    $self->debug('dialog build, text: ' . $text . ', job: ' . encode_json($job) . ', errors: ' . encode_json($errors));

    unless (defined($job)) {
        return {
            text => 'Error: ' . (scalar(@$errors > 0) ? $errors->[0]->{error} : 'unknown error')
        };
    }

    my $id = $self->nextBuildId();
    $self->redis->zadd("anyjob:builds", time(), $id);
    $self->redis->set('anyjob:build:' . $id, encode_json({
            type   => $job->{type},
            nodes  => $job->{nodes},
            params => $job->{params},
            props  => $job->{props}
        }));

    my $dialog = $self->getJobDialog($job, $id);
    unless (defined($dialog)) {
        return {
            text => 'Error: unknown error'
        }
    }

    unless (defined($self->sendDialog($trigger_id, $dialog))) {
        return {
            text => 'Error: failed to open dialog'
        }
    }

    return undef;
}

sub getJobDialog {
    my $self = shift;
    my $job = shift;
    my $id = shift;

    my $config = $self->config->getJobConfig($job->{type});
    unless (defined($config)) {
        return undef;
    }

    my $dialog = {
        callback_id  => $id,
        title        => 'Create job \'' . ($config->{label} || $job->{type}) . '\'' .
            ' on ' . join(', ', @{$job->{nodes}}),
        submit_label => 'Create',
        elements     => []
    };

    my $params = $self->config->getJobParams($job->{type});
    foreach my $param (@$params) {
        if (defined(my $element = $self->getParamForDialog($param, $job->{params}))) {
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
            type    => '
        select',
            name    => $param->{name},
            label   => $param->{label},
            value   => $values->{$param->{name}} ? 1 : 0,
            options => [
                {
                    label => '
        Yes',
                    value => 1
                },
                {
                    label => '
        No',
                    value => 0
                }
            ]
        };
    } elsif ($param->{type} eq '
        text') {
        my $value = $values->{$param->{name}};
        return {
            type     => '
        text',
            name     => $param->{name},
            label    => $param->{label},
            (defined($value) ? (value => $value) : ()),
            optional => $param->{required} ? 0 : 1,
        };
    } elsif ($param->{type} eq '
        textarea') {
        my $value = $values->{$param->{name}};
        return {
            type     => '
        textarea',
            name     => $param->{name},
            label    => $param->{label},
            (defined($value) ? (value => $value) : ()),
            optional => $param->{required} ? 0 : 1,
        };
    } elsif ($param->{type} eq '
        combo') {
        my $value = $values->{$param->{name}};
        unless (defined($value) and grep {$_->{value} eq $value} @{$param->{data}}) {
            $value = undef;
        }
        return {
            type     => '
        select',
            name     => $param->{name},
            label    => $param->{label},
            (defined($value) ? (value => $value) : ()),
            optional => $param->{required} ? 0 : 1,
            options  => [ map {{ label => $_->{label}, value => $_->{value} }} @{$param->{data}} ]
        };
    }

    return undef;
}
