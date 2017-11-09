app.directive('jobs', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            label: '@label',
            action: '&action',
            jobs: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();

            $scope.jobs.splice(0, $scope.jobs.length);
            $scope.jobs.push({isCollapsed: false});

            $scope.addJob = function () {
                $scope.collapseJobs();
                $scope.jobs.push({isCollapsed: false});
            };

            $scope.collapseJobs = function (exceptIndex) {
                angular.forEach($scope.jobs, function (job, index) {
                    if (index !== exceptIndex) {
                        job.isCollapsed = true;
                    }
                });
            };

            $scope.removeJob = function (index) {
                if ($scope.jobs.length > 1) {
                    $scope.jobs.splice(index, 1);
                }
            };
        },

        templateUrl: 'app/shared/jobs/template.html'
    };
});
