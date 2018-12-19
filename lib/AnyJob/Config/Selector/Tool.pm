package AnyJob::Config::Selector::Tool;

###############################################################################
# Config selector implementation used in tool anyjob component.
#
# Author:       LightStar
# Created:      19.12.2018
# Last update:  19.12.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(
    DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_JOBSETS_CONFIG_PATH DEFAULT_SEMAPHORES_CONFIG_PATH
);

use base 'AnyJob::Config::Selector::Base';

###############################################################################
# Add additional files needed by daemon component into configuration.
#
sub addConfig {
    my $self = shift;

    my $config = $self->config;

    $self->addConfigFromFile('semaphore.cfg');

    $self->addConfigFromDir(($config->nodes_path || DEFAULT_NODES_CONFIG_PATH), 'node');
    $self->addConfigFromDir(File::Spec->catdir(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'work'), 'job');
    $self->addConfigFromDir(($config->jobsets_path || DEFAULT_JOBSETS_CONFIG_PATH), 'jobset');
    $self->addConfigFromDir(($config->semaphores_path || DEFAULT_SEMAPHORES_CONFIG_PATH), 'semaphore');
}

1;
