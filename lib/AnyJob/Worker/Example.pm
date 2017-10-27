package AnyJob::Worker::Example;

use strict;
use warnings;
use utf8;

use JSON::XS;

sub run {
    my $class = shift;
    my $worker = shift;
    my $id = shift;
    my $job = shift;

    if ($worker->node eq "test") {
        $worker->debug("Redirect job '" . $id . "' on node '" . $worker->node .
            "' to node 'broadcast': " . encode_json($job));
        $worker->sendRedirect($id, "broadcast");
        return;
    }

    $worker->debug("Perform job '" . $id . "' on node '" . $worker->node . "': " . encode_json($job));
    $worker->sendRun($id);

    sleep(2);

    $worker->sendLog($id, "Step 1");

    sleep(5);

    $worker->sendLog($id, "Step 2");

    sleep(10);

    $worker->debug("Finish performing job '" . $id . "'");
    $worker->sendSuccess($id, "done");
}

1;
