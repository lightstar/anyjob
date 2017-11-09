app.controller('createJobs', function ($scope, $http, configService, createService) {

    $scope.create = function () {
        var jobs = [];

        for (var i = 0; i < $scope.jobs.length; i++) {
            var job = $scope.jobs[i];
            if (job.proto === null) {
                continue;
            }

            deleteEmptyFields(job.nodes, job.params, job.props);

            var nodes = [];
            angular.forEach(job.nodes, function (value, key) {
                nodes.push(key);
            });

            jobs.push({
                type: job.proto.type,
                nodes: nodes,
                params: job.params,
                props: job.props
            });
        }

        console.log("jobs: " + JSON.stringify(jobs));

        if (jobs.length === 0) {
            return;
        }

        createService.create(jobs, function (success, error, status, statusText) {
            if (status !== 200) {
                alert("Error: " + (statusText || "unknown") + " (" + status + ")");
            } else if (success !== 1) {
                if (error !== "") {
                    alert("Error: " + error);
                } else {
                    alert("Error: unknown");
                }
            } else {
                alert("Jobs created");
            }
        });
    };

    configService.load(function (config, status, statusText) {
        if (status === 200) {
            $scope.config = config;
            $scope.jobs = [];
        } else {
            alert("Error: " + (statusText || "unknown") + " (" + status + ")");
        }
    });
});
