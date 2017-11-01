app.controller('CreateJob', function ($scope, $http, $location, CreatorService) {
    $scope.jobs = [];
    $scope.job = null;

    CreatorService.loadJobs($http, function (jobs) {
        $scope.jobs = jobs;
        $scope.job = null;
    });
});
