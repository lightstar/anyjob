package AnyJob::Config::Selector::Worker;

###############################################################################
# Config selector implementation used in worker anyjob component.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  05.03.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_WORKERS_CONFIG_PATH);

use base 'AnyJob::Config::Selector::Base';

###############################################################################
# Add additional files needed by worker component into configuration.
#
sub addConfig {
    my $self = shift;
    my $config = $self->config;

    $self->addConfigFromFile('worker.cfg', 'worker');

    $self->addConfigFromFile(File::Spec->catfile(($config->nodes_path || DEFAULT_NODES_CONFIG_PATH),
        $config->node . '.cfg'), 'node_' . $config->node);

    if (defined($ENV{ANYJOB_WORKER})) {
        $self->addComponentConfig(($config->workers_path || DEFAULT_WORKERS_CONFIG_PATH), 'worker',
            $ENV{ANYJOB_WORKER});
    }

    if (defined($ENV{ANYJOB_JOB})) {
        $self->addComponentConfig(File::Spec->catfile(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'work'), 'job',
            $ENV{ANYJOB_JOB});
    } else {
        $self->addConfigFromDir(File::Spec->catdir(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'work'), 'job');
    }
}

1;
