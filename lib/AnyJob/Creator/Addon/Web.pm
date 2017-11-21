package AnyJob::Creator::Addon::Web;

use strict;
use warnings;
use utf8;

use File::Spec;
use Scalar::Util qw(reftype);

use AnyJob::Utils qw(getFileContent);

use base 'AnyJob::Creator::Addon::Base';

sub getEventTemplate {
    my $self = shift;

    unless (exists($self->{appEventTemplate})) {
        $self->{appEventTemplate} =
            getFileContent(File::Spec->catdir($self->config->templates_path, 'observers/app/web-event.html'));
    }

    return $self->{appEventTemplate};
}

sub preprocessJobs {
    my $self = shift;
    my $jobs = shift;

    if (ref($jobs) ne "ARRAY" or scalar(@$jobs) == 0) {
        return;
    }

    foreach my $job (@$jobs) {
        if (defined($job->{params}) and ref($job->{params}) eq "HASH") {
            $self->preprocessJobParams($job->{params});
        }

        if (defined($job->{props}) and ref($job->{props}) eq "HASH") {
            $self->preprocessJobParams($job->{props});
        }
    }
}

sub preprocessJobParams {
    my $self = shift;
    my $params = shift;

    while (my ($name, $value) = each(%$params)) {
        if (ref($value) ne "" and reftype($value) eq "SCALAR") {
            $params->{$name} = $$value;
        }
    }
}

1;
