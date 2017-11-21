package AnyJob::Creator::Addon::Slack;

use strict;
use warnings;
use utf8;

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

1;
