package AnyJob::Creator::Web;

use strict;
use warnings;
use utf8;

use File::Spec;
use Scalar::Util qw(reftype);

use AnyJob::Utils qw(getFileContent);

use base 'AnyJob::Creator';

sub getWebAppEventTemplate {
    my $self = shift;

    unless (exists($self->{appEventTemplate})) {
        $self->{appEventTemplate} =
            getFileContent(File::Spec->catdir($self->config->templates_path, 'observers/app/web-event.html'));
    }

    return $self->{appEventTemplate};
}

sub preprocessWebAppJobs {
    my $self = shift;
    my $jobs = shift;

    if (ref($jobs) ne "ARRAY" or scalar(@$jobs) == 0) {
        return;
    }

    foreach my $job (@$jobs) {
        if (defined($job->{params}) and ref($job->{params}) eq "HASH") {
            $self->preprocessWebAppJobParams($job->{params});
        }

        if (defined($job->{props}) and ref($job->{props}) eq "HASH") {
            $self->preprocessWebAppJobParams($job->{props});
        }
    }
}

sub preprocessWebAppJobParams {
    my $self = shift;
    my $params = shift;

    while (my ($name, $value) = each(%$params)) {
        if (ref($value) ne "" and reftype($value) eq "SCALAR") {
            $params->{$name} = $$value;
        }
    }
}

1;
