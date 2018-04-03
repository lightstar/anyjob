package AnyJob::Config::Selector::Daemon;

###############################################################################
# Config selector implementation used in daemon anyjob component.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  03.04.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(
    DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_OBSERVERS_CONFIG_PATH DEFAULT_WORKERS_CONFIG_PATH
    DEFAULT_SEMAPHORES_CONFIG_PATH
);

use base 'AnyJob::Config::Selector::Base';

###############################################################################
# Add additional files needed by daemon component into configuration.
#
sub addConfig {
    my $self = shift;

    my $config = $self->config;

    $self->addConfigFromFile('daemon.cfg', 'daemon');
    $self->addConfigFromFile('worker.cfg', 'worker');
    $self->addConfigFromFile('semaphore.cfg');

    $self->addConfigFromDir(($config->nodes_path || DEFAULT_NODES_CONFIG_PATH), 'node');
    $self->addConfigFromDir(File::Spec->catdir(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'work'), 'job');
    $self->addConfigFromDir(($config->workers_path || DEFAULT_WORKERS_CONFIG_PATH), 'worker');
    $self->addConfigFromDir(($config->observers_path || DEFAULT_OBSERVERS_CONFIG_PATH), 'observer');
    $self->addConfigFromDir(($config->semaphores_path || DEFAULT_SEMAPHORES_CONFIG_PATH), 'semaphore');
}

1;
