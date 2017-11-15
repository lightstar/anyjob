app.controller('creatorController', function ($scope, $http, $compile, creatorService) {
    $scope.jobs = [];
    $scope.events = [];
    $scope.control = {reset: null};

    $scope.create = function () {
        var jobs = [];

        angular.forEach($scope.jobs, function (job) {
            if (job.proto === null) {
                return;
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
        });

        creatorService.create(jobs, function (error) {
            if (error !== "") {
                $scope.alert("Error: " + error, "danger", true);
            } else {
                var message = jobs.length > 1 ? "Jobs created" : "Job created";
                $scope.alert(message, "success");
                $scope.control.reset();
            }
        });
    };

    $scope.$watch('config.auth', function (auth) {
        if (auth.user === "") {
            return;
        }

        creatorService.observe(auth, function (events) {
            $scope.$apply(function() {
                angular.forEach(events, function (event) {
                    $scope.events.push(event);
                });
            });
        });
    });
});
