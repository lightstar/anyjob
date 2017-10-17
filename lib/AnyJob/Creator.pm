package AnyJob::Creator;

use strict;
use warnings;
use utf8;

use JSON::XS;

use base 'AnyJob::Base';

sub new {
    my $class = shift;
    my %args = @_;
    $args{type} = "creator";
    my $self = $class->SUPER::new(%args);
    return $self;
}

sub createJob {
    my $self = shift;
    my $node = shift;
    my $type = shift;
    my $params = shift;
    $params ||= {};

    unless ($self->config->isJobSupported($type, $node)) {
        $self->error("Job with type '" . $type . "' is not supported on node '" . $node . "'");
        return;
    }

    $self->redis->rpush("anyjob:queue:" . $node, encode_json({ type => $type, params => $params }));
}

sub createJobSet {
    my $self = shift;
    my $jobs = shift;

    unless (scalar(@$jobs)) {
        return;
    }

    foreach my $job (@$jobs) {
        unless ($self->config->isJobSupported($job->{type}, $job->{node})) {
            $self->error("Job with type '" . $job->{type} . "' is not supported on node '" . $job->{node} . "'");
            return;
        }
        $job->{params} ||= {};
    }

    $self->redis->rpush("anyjob:queue", encode_json({ jobset => 1, jobs => $jobs }));
}

1;
