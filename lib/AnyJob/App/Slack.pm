package AnyJob::App::Slack;

use strict;
use warnings;
use utf8;

use Dancer2 qw(!config !debug !error);
use Dancer2::Plugin::AnyJob;

set serializer => 'JSON';
set charset => 'UTF-8';

get '/' => sub {
        debug("slack /: " . request->body);
        return {};
    };

get '/create' => sub {
        debug("slack /create: " . request->body);
        return {};
        };

1;
