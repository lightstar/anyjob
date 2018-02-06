package AnyJob::Config::Selector::Daemon;

###############################################################################
# Config selector implementation used in daemon anyjob component.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  06.02.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_OBSERVERS_CONFIG_PATH);

use base 'AnyJob::Config::Selector::Base';

###############################################################################
# Add additional files needed by daemon component into configuration.
#
sub addConfig {
    my $self = shift;

    my $config = $self->config;

    $self->addConfigFromFile('daemon.cfg', 'daemon');
    $self->addConfigFromFile('worker.cfg', 'worker');

    $self->addConfigFromDir(($config->nodes_path || DEFAULT_NODES_CONFIG_PATH), 'node');
    $self->addConfigFromDir(File::Spec->catdir(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'work'), 'job');
    $self->addConfigFromDir(($config->observers_path || DEFAULT_OBSERVERS_CONFIG_PATH), 'observer');
}

1;
