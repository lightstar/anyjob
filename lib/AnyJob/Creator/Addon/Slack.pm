package AnyJob::Creator::Addon::Slack;

use strict;
use warnings;
use utf8;

use AnyJob::Utils qw(moduleName requireModule);

use base 'AnyJob::Creator::Addon::Base';

sub checkToken {
    my $self = shift;
    my $token = shift;

    my $slack = $self->config->section('slack') || {};
    if (defined($slack->{token}) and defined($token) and $slack->{token} eq $token) {
        return 1;
    }

    return undef;
}

sub getBuilder {
    my $self = shift;
    my $command = shift;

    my $name = $self->getBuilderNameByCommand($command);
    unless (defined($name)) {
        return undef;
    }

    if (exists($self->{builders}) and exists($self->{builders}->{$name})) {
        return $self->{builders}->{$name};
    }

    $self->{builders} ||= {};

    my $config = $self->config->getBuilderConfig('slack_' . $name);
    my $module = 'AnyJob::Creator::Builder::Slack::' . moduleName($config->{module});
    requireModule($module);

    $self->{builders}->{$name} = $module->new(parent => $self->{parent}, name => $name);
    return $self->{builders}->{$name};
}

sub getBuilderNameByCommand {
    my $self = shift;
    my $command = shift;

    unless (exists($self->{buildersByCommand})) {
        $self->generateBuildersByCommand();
    }

    return $self->{buildersByCommand}->{$command};
}

sub generateBuildersByCommand {
    my $self = shift;

    my %builders;
    foreach my $name (@{$self->config->getAllBuilders()}) {
        unless ($name =~ s/^slack_//) {
            next;
        }

        my $config = $self->config->getBuilderConfig('slack_' . $name) || {};
        foreach my $command (grep {$_ ne ''} ($config->{command} || '', split(/\s*,\s*/, $config->{aliases} || ''))) {
            $builders{$command} = $name;
        }
    }

    $self->{buildersByCommand} = \%builders;
}

1;
