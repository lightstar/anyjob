package AnyJob::Controller::Global::Clean;

use strict;
use warnings;
use utf8;

use JSON::XS;

use AnyJob::Constants::Events qw(EVENT_CLEAN_JOBSET);

use base 'AnyJob::Controller::Global';

sub process {
    my $self = shift;

    my $nodeConfig = $self->config->getNodeConfig() || {};

    my $jobSetLimit = $nodeConfig->{jobset_clean_limit} || $self->config->limit || 10;
    $self->cleanJobSets($jobSetLimit);

    my $buildLimit = $nodeConfig->{build_clean_limit} || $self->config->limit || 10;
    $self->cleanBuilds($buildLimit);
}

sub cleanJobSets {
    my $self = shift;
    my $limit = shift;

    my %ids = $self->redis->zrangebyscore('anyjob:jobsets', '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        if (defined(my $jobSet = $self->getJobSet($id))) {
            $self->sendEvent(EVENT_CLEAN_JOBSET, {
                    id    => $id,
                    props => $jobSet->{props},
                    jobs  => $jobSet->{jobs}
                });
        } else {
            $self->error('Cleaned jobset \'' . $id . '\' not found');
        }

        $self->cleanJobSet($id);
    }
}

sub cleanBuilds {
    my $self = shift;
    my $limit = shift;

    my %ids = $self->redis->zrangebyscore('anyjob:builds', '-inf', time(), 'WITHSCORES',
        'LIMIT', '0', $limit);

    foreach my $id (keys(%ids)) {
        $self->cleanBuild($id);
    }
}

1;
