/**
 * Define creator page controller. Its main job is to let user describe what jobs he/she wants to create and than
 * send request to server to actually create them.
 * In parallel observing is launched so all private events happening with created jobs are immediately shown.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  24.12.2018
 */

app.controller('creatorController', function ($scope, $http, $compile, creatorService) {
    $scope.jobs = [];
    $scope.delay = {
        label: "Delay"
    };
    $scope.events = [];
    $scope.control = {reset: null, event: null};

    /**
     * Prepare jobs for processing.
     *
     * @return {array} array of objects with prepared jobs data.
     */
    function prepareJobs() {
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

        return jobs;
    }

    /**
     * Prepare delay data for processing.
     *
     * @return {object} object with prepared delay data.
     */
    function prepareDelay() {
        var delay = {};

        if ($scope.delay.time !== undefined && $scope.delay.time !== null) {
            delay.time = $scope.delay.time;
            delay.summary = 'summary';
        }

        return delay;
    }

    var isWaiting = false;

    /**
     * Create or delay jobs.
     */
    $scope.processJobs = function () {
        if (isWaiting) {
            return;
        }

        isWaiting = true;
        var jobs = prepareJobs();
        var delay = prepareDelay();

        var callback = function(message, error) {
            if (error !== '') {
                $scope.alert('Error: ' + error, 'danger', true);
            } else {
                $scope.alert(message, 'success');
                $scope.control.reset();
            }
            isWaiting = false;
        };


        if (delay.time !== undefined) {
            creatorService.delay(delay, jobs, function (error) {
                callback(jobs.length > 1 ? 'Jobs delayed' : 'Job delayed', error);
            });
        } else {
            creatorService.create(jobs, function (error) {
                callback(jobs.length > 1 ? 'Jobs created' : 'Job created', error);
            });
        }
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
