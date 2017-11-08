app.controller('createJob', function ($scope, $http, $location, creatorService) {
    $scope.initData = function (jobs, props) {
        $scope.jobs = jobs;
        $scope.props = props;

        $scope.initGroups();

        $scope.data = {job: null, group: null};
        $scope.resetData();
    };

    $scope.initGroups = function () {
        $scope.groups = [];
        $scope.jobsByGroup = {null: []};

        angular.forEach($scope.jobs, function (job) {
            if (job.group === undefined || job.group === "") {
                job.group = null;
            }

            if (job.group !== null && $scope.groups.indexOf(job.group) === -1) {
                $scope.groups.push(job.group);
                $scope.jobsByGroup[job.group] = [];
            }

            $scope.jobsByGroup[job.group].push(job);
        });
    };

    $scope.resetData = function () {
        $scope.data.nodes = {};
        $scope.data.params = {};
        $scope.data.props = {};
    };

    $scope.initData([], []);

    $scope.createJobs = function () {
        deleteEmptyFields($scope.data.nodes, $scope.data.params, $scope.data.props);

        var type = $scope.data.job.type;
        var nodes = [];
        angular.forEach($scope.data.nodes, function (value, key) {
            nodes.push(key);
        });

        var jobs = [{
            type: type,
            nodes: nodes,
            params: $scope.data.params,
            props: $scope.data.props
        }];

        console.log("data: " + JSON.stringify($scope.data));
        console.log("jobs: " + JSON.stringify(jobs));

        creatorService.createJobs($http, jobs, function (success, error, status, statusText) {
            if (status !== 200) {
                alert("Error: " + (statusText || "unknown") + " (" + status + ")");
            } else if (success !== 1) {
                if (error !== "") {
                    alert("Error: " + error);
                } else {
                    alert("Error: unknown");
                }
            } else {
                alert("Job created");
            }
        });
    };

    creatorService.loadJobs($http, function (jobs, props, status, statusText) {
        $scope.initData(jobs, props);
        if (status !== 200) {
            alert("Error: " + (statusText || "unknown") + " (" + status + ")");
        }
    });
});
