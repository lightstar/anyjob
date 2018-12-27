/**
 * Define creator page controller. Its main job is to let user describe what jobs he/she wants to create and than
 * send request to server to actually create them.
 * In parallel observing is launched so all private events happening with created jobs are immediately shown.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  27.12.2018
 */

app.controller('creatorController', function ($scope, $http, $compile, $uibModal, creatorService) {
    $scope.jobs = [];
    $scope.delay = {
        label: 'Delay'
    };
    $scope.events = [];
    $scope.control = {reset: EMPTY_FN, event: EMPTY_FN};

    /**
     * Prepare jobs for processing.
     *
     * @param {Function} callback - callback function which will be called with prepared array of job data objects as
     *                              argument.
     */
    function prepareJobs(callback) {
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

        callback(jobs);
    }

    /**
     * Prepare delay data for processing.
     *
     * @param {array} jobs        - array of hashes with prepared job data.
     * @param {Function} callback - callback function which will be called with prepared delay data object as argument.
     *                              If user denies operation, resulting object will be null.
     */
    function prepareDelay(jobs, callback) {
        var delay = {};

        if ($scope.delay.time !== undefined && $scope.delay.time !== null) {
            delay.time = $scope.delay.time;
        }

        $uibModal.open({
            component: 'delaySummaryDialog',
            resolve: {
                summary: function () {
                    return jobs[0].type;
                }
            }
        }).result.then(function (summary) {
            delay.summary = summary;
            callback(delay);
        }, function () {
            callback(null);
        });
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

        var callback = function (message, error) {
            if (error !== '') {
                $scope.alert('Error: ' + error, 'danger', true);
            } else {
                $scope.alert(message, 'success');
                $scope.control.reset();
            }
            isWaiting = false;
        };

        prepareJobs(function (jobs) {
            prepareDelay(jobs, function (delay) {
                if (delay === null) {
                    isWaiting = false;
                    return;
                }

                if (delay.time !== undefined) {
                    creatorService.delay(delay, jobs, function (error) {
                        callback(jobs.length > 1 ? 'Jobs delayed' : 'Job delayed', error);
                    });
                } else {
                    creatorService.create(jobs, function (error) {
                        callback(jobs.length > 1 ? 'Jobs created' : 'Job created', error);
                    });
                }
            });
        });
    };

    /**
     * Observing begins only after config is loaded and observer panel initialized.
     */
    $scope.$watchGroup(['config.auth', 'control.event'], function () {
        if ($scope.config.auth.user === '' || $scope.control.event !== EMPTY_FN) {
            return;
        }

        creatorService.observe($scope.config.auth, function (event) {
            $scope.$apply(function () {
                $scope.control.event(event);
            });
        });
    });
});
