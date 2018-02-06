package AnyJob::Config::Selector::Creator;

###############################################################################
# Config selector implementation used in creator anyjob component.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  06.02.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(
    DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH DEFAULT_CREATORS_CONFIG_PATH
    DEFAULT_BUILDERS_CONFIG_PATH
    );

use base 'AnyJob::Config::Selector::Base';

###############################################################################
# Add additional files needed by creator component into configuration.
#
sub addConfig {
    my $self = shift;

    my $config = $self->config;

    $self->addConfigFromFile('creator.cfg', 'creator');

    $self->addConfigFromDir(($config->nodes_path || DEFAULT_NODES_CONFIG_PATH), 'node');
    $self->addConfigFromDir(File::Spec->catdir(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH), 'create'), 'job');
    $self->addConfigFromDir(($config->creators_path || DEFAULT_CREATORS_CONFIG_PATH), 'creator');
    $self->addConfigFromDir(($config->builders_path || DEFAULT_BUILDERS_CONFIG_PATH), 'builder');
}

1;
