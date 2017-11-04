app.controller('createJob', function ($scope, $http, $location, creatorService) {
    $scope.initData = function(jobs, props) {
        $scope.jobs = jobs;
        $scope.props = props;
        $scope.data = { job: null };
        $scope.resetData();
    };

    $scope.resetData = function() {
        $scope.data.nodes = {};
        $scope.data.params = {};
        $scope.data.props = {};
    };

    $scope.initData([], []);

    $scope.createJob = function () {
        deleteEmptyFields($scope.data.nodes, $scope.data.params, $scope.data.props);

        var job = {
            type: $scope.data.job.type,
            nodes: $scope.data.nodes,
            params: $scope.data.params,
            props: $scope.data.props
        };

        console.log("data: " + JSON.stringify($scope.data));
        console.log("job: " + JSON.stringify(job));
    };

    creatorService.loadJobs($http, function (jobs, props) {
        $scope.initData(jobs, props)
    });
});
