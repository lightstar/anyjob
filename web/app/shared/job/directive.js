app.directive('job', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            job: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();

            $scope.reset = function () {
                $scope.job.nodes = {};
                $scope.job.params = {};
                $scope.job.props = {};
            };

            $scope.job.group = null;
            $scope.job.proto = null;
            $scope.reset();
        },

        templateUrl: 'app/shared/job/template.html'
    };
});
