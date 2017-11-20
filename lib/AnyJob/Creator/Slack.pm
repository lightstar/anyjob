package AnyJob::Creator::Slack;

use strict;
use warnings;
use utf8;

use base 'AnyJob::Creator';

sub checkSlackToken {
    my $self = shift;
    my $token = shift;

    my $config = $self->config->section("slack") || {};
    if (defined($config->{token}) and defined($token) and $config->{token} eq $token) {
        return 1;
    }

    return undef;
}

sub isSlackUserAllowed {
    my $self = shift;
    my $user = shift;

    my $allowed_users;

    if (exists($self->{allowed_users})) {
        $allowed_users = $self->{allowed_users};
    } else {
        my $config = $self->config->section("app") || {};
        if (defined($config->{allowed_users})) {
            $allowed_users = { map {$_ => 1} split(/\s*,\s*/, $config->{allowed_users}) };
        }
        $self->{allowed_users} = $allowed_users;
    }

    if (defined($allowed_users) and defined($user) and exists($allowed_users->{$user})) {
        return 1;
    }

    return undef;
}

1;
