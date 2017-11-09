app.directive('job', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            job: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();

            $scope.resetJob = function () {
                $scope.job.nodes = {};
                $scope.job.params = {};
                $scope.job.props = {};
            };

            $scope.job.group = null;
            $scope.job.proto = null;
            $scope.resetJob();
        },

        templateUrl: 'app/shared/job/template.html'
    };
});
