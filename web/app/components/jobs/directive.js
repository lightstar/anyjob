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
            $scope.isValid = false;

            $scope.add = function () {
                $scope.collapse();
                $scope.jobs.push({isCollapsed: false});
                if ($scope.isValid) {
                    $scope.isValid = false;
                }
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
                $scope.validate();
            };

            $scope.validate = function() {
                var isValid = true;

                angular.forEach($scope.jobs, function(job) {
                    if (!job.isValid) {
                        isValid = false;
                    }
                });

                $scope.isValid = isValid;
            };

            $scope.control.reset = function() {
                $scope.jobs.splice(0, $scope.jobs.length);
                $scope.add();
            };

            $scope.control.reset();
        },

        templateUrl: 'app/components/jobs/template.html'
    };
});
