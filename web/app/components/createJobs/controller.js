app.controller('createJobs', function ($scope, $http, createService) {
    $scope.initData = function (jobs, props) {
        $scope.jobs = jobs;
        $scope.props = props;

        $scope.initGroups();

        $scope.jobsToCreate = [{job: null, group: null, isCollapsed: false}];
        $scope.resetJobToCreate($scope.jobsToCreate[0]);
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

    $scope.resetJobToCreate = function (jobToCreate) {
        jobToCreate.nodes = {};
        jobToCreate.params = {};
        jobToCreate.props = {};
    };

    $scope.addJobToCreate = function() {
        $scope.collapseAll();
        angular.forEach($scope.jobsToCreate, function(jobToCreate) {
            jobToCreate.isCollapsed = true;
        });
        $scope.jobsToCreate.push({job: null, group: null, isCollapsed: false});
    };

    $scope.collapseAll = function(exceptIndex) {
        angular.forEach($scope.jobsToCreate, function(jobToCreate, index) {
            if (index !== exceptIndex) {
                jobToCreate.isCollapsed = true;
            }
        });
    };

    $scope.removeJobToCreate = function(index) {
        if ($scope.jobsToCreate.length > 1) {
            $scope.jobsToCreate.splice(index, 1);
        }
    };

    $scope.createJobs = function () {
        var jobsToCreate = [];

        for (var i = 0; i < $scope.jobsToCreate.length; i++) {
            var jobToCreate = $scope.jobsToCreate[i];
            if (jobToCreate.job === null) {
                continue;
            }

            deleteEmptyFields(jobToCreate.nodes, jobToCreate.params, jobToCreate.props);

            var type = jobToCreate.job.type;
            var nodes = [];
            angular.forEach(jobToCreate.nodes, function (value, key) {
                nodes.push(key);
            });

            jobsToCreate.push({
                type: type,
                nodes: nodes,
                params: jobToCreate.params,
                props: jobToCreate.props
            });
        }

        console.log("jobs: " + JSON.stringify(jobsToCreate));

        if (jobsToCreate.length === 0) {
            return;
        }

        createService.createJobs(jobsToCreate, function (success, error, status, statusText) {
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

    $scope.initData([], []);

    createService.loadJobs(function (jobs, props, status, statusText) {
        $scope.initData(jobs, props);
        if (status !== 200) {
            alert("Error: " + (statusText || "unknown") + " (" + status + ")");
        }
    });


});
