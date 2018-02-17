/**
 * Define creator page controller. Its main job is to let user describe what jobs he/she wants to create and than
 * send request to server to actually create them.
 * In parallel observing is launched so all private events happening with created jobs are immediately shown.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  16.02.2018
 */

app.controller('creatorController', function ($scope, $http, $compile, creatorService) {
    $scope.jobs = [];
    $scope.events = [];
    $scope.control = {reset: null, event: null};

    var isCreating = false;

    /**
     * Create jobs.
     */
    $scope.create = function () {
        if (isCreating) {
            return;
        }

        isCreating = true;
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
            if (error !== '') {
                $scope.alert('Error: ' + error, 'danger', true);
            } else {
                var message = jobs.length > 1 ? 'Jobs created' : 'Job created';
                $scope.alert(message, 'success');
                $scope.control.reset();
            }
            isCreating = false;
        });
    };

    /**
     * Observing begins only after config is loaded and observer panel initialized.
     */
    $scope.$watchGroup(['config.auth', 'control.event'], function () {
        if ($scope.config.auth.user === '' || $scope.control.event === null) {
            return;
        }

        creatorService.observe($scope.config.auth, function (event) {
            $scope.$apply(function () {
                $scope.control.event(event);
            });
        });
    });
});
