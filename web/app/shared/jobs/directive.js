app.directive('jobs', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control',
            label: '@label',
            action: '&action',
            jobs: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.isValid = true;

            $scope.add = function () {
                $scope.collapse();
                $scope.jobs.push({isCollapsed: false});
            };

            $scope.collapse = function (exceptIndex) {
                angular.forEach($scope.jobs, function (job, index) {
                    if (index !== exceptIndex) {
                        job.isCollapsed = true;
                    }
                });
            };

            $scope.remove = function (index) {
                if ($scope.jobs.length > 1) {
                    $scope.jobs.splice(index, 1);
                }
            };

            $scope.control.reset = function() {
                $scope.jobs.splice(0, $scope.jobs.length);
                $scope.add();
            };

            $scope.control.reset();
        },

        templateUrl: 'app/shared/jobs/template.html'
    };
});
