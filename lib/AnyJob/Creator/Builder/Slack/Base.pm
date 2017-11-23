package AnyJob::Creator::Builder::Slack::Base;

use strict;
use warnings;
use utf8;

use JSON::XS;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

use base 'AnyJob::Creator::Builder::Base';

sub getBuilderConfig {
    my $self = shift;
    return $self->config->getBuilderConfig('slack_' . $self->name);
}

sub ua {
    my $self = shift;
    if (exists($self->{ua})) {
        return $self->{ua};
    }

    $self->{ua} = LWP::UserAgent->new();
    return $self->{ua};
}

sub isUserAllowed {
    my $self = shift;
    my $user = shift;

    my $users;

    if (exists($self->{users})) {
        $users = $self->{users};
    } else {
        my $config = $self->getBuilderConfig();
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

sub sendApiCommand {
    my $self = shift;
    my $command = shift;
    my $data = shift;

    my $slack = $self->config->section('slack') || {};
    unless (defined($slack->{api}) and defined($slack->{api_token})) {
        require Carp;
        Carp::confess('No api URL or token for slack');
    }

    my $url = $slack->{api} . $command;
    my $request = POST($url,
        Content_Type  => 'application/json',
        Authorization => 'Bearer ' . $slack->{api_token},
        Content       => encode_json($data)
    );

    my $result = $self->ua->request($request);
    unless ($result->is_success) {
        $self->error('Slack command failed, url: ' . $url . ', response: ' . $result->content);
        return undef;
    } else {
        my $response;
        eval {
            $response = decode_json($result->content);
        };
        if ($@ or not $response->{ok}) {
            $self->error('Slack command failed, url: ' . $url . ', response: ' . $result->content);
            return undef;
        }
    }

    return 1;
}

sub sendDialog {
    my $self = shift;
    my $trigger = shift;
    my $dialog = shift;

    return $self->sendApiCommand('dialog.open', {
            trigger_id => $trigger,
            dialog     => $dialog
        });
}

1;