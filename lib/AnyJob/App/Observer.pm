package AnyJob::App::Observer;

use strict;
use warnings;
use utf8;

use CGI::Deurl::XS;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;
use Dancer2::Plugin::WebSocket;

set plugins => {
        WebSocket => {
            mount_path => '/ws',
            serializer => {
                utf8         => 1,
                allow_nonref => 1
            }
        }
    };

websocket_on_open sub {
        my $conn = shift;
        my $env = shift;

        my $query = CGI::Deurl::XS::parse_query_string($env->{'QUERY_STRING'});
        my $user = $query->{user} || '';
        my $pass = $query->{pass} || '';

        unless (config->checkAuth($user, $pass)) {
            return;
        }

        my $config = config->section('app') || {};
        my $delay = $config->{observer_delay} || 1;
        my $timer = AnyEvent->timer(after => $delay, interval => $delay, cb => sub {
                my $events = creator->receivePrivateEvents('u' . $user);
                if (scalar(@$events)) {
                    $conn->send($events);
                }
            });
        $conn->on(close => sub {
                undef $timer;
            });
    };

1;
