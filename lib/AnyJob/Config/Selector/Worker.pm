package AnyJob::Config::Selector::Worker;

###############################################################################
# Config selector implementation used in worker anyjob component.
#
# Author:       LightStar
# Created:      06.02.2018
# Last update:  07.02.2018
#

use strict;
use warnings;
use utf8;

use File::Spec;

use AnyJob::Constants::Defaults qw(DEFAULT_NODES_CONFIG_PATH DEFAULT_JOBS_CONFIG_PATH);

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

    if (defined($ENV{ANYJOB_JOB})) {
        my $type = $ENV{ANYJOB_JOB};
        my $configFile = $type . '.cfg';
        unless ($self->addConfigFromFile(File::Spec->catfile(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH),
                'work', $configFile), 'job_' . $type)
        ) {
            my $pathSeparator = File::Spec->catfile('', '');
            while ($configFile =~ s/_/$pathSeparator/) {
                if ($self->addConfigFromFile(File::Spec->catfile(($config->jobs_path || DEFAULT_JOBS_CONFIG_PATH),
                        'work', $configFile), 'job_' . $type)
                ) {
                    last;
                }
            }
        }
    }
}

1;
