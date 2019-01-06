/**
 * Define creator page controller. Its main job is to let user describe what jobs he/she wants to create and than
 * send request to server to actually create or delay them.
 *
 * In parallel observing is launched so all private events happening with created jobs and delayed works are
 * immediately shown.
 *
 * Also additional mode is available used to display all existing delayed works and perform operations with them.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  06.01.2019
 */

app.controller('creatorController', function ($scope, $http, $compile, $uibModal, creatorService) {
    $scope.jobs = [];
    $scope.delay = {
        label: 'Delay'
    };
    $scope.eventListeners = [];
    $scope.control = {reset: EMPTY_FN};

    $scope.mode = CREATOR_MODE_JOBS;

    /**
     * Change mode to 'delayed works'.
     */
    $scope.goToDelayedWorksMode = function () {
        $scope.mode = CREATOR_MODE_DELAYED_WORKS;
    };

    /**
     * Change mode to 'create/delay jobs'.
     */
    $scope.goToJobsMode = function () {
        $scope.mode = CREATOR_MODE_JOBS;
    };

    /**
     * Determine if current mode is 'delayed works'.
     *
     * @return {boolean} true if current mode is 'delayed works'.
     */
    $scope.isDelayedWorksMode = function () {
        return $scope.mode === CREATOR_MODE_DELAYED_WORKS;
    };

    /**
     * Determine if current mode is 'delayed works'.
     *
     * @return {boolean} true if current mode is 'create/delay jobs'.
     */
    $scope.isJobsMode = function () {
        return $scope.mode === CREATOR_MODE_JOBS;
    };

    /**
     * Show error message.
     *
     * @param {string} message - error message.
     */
    $scope.error = function (message) {
        $scope.alert('Error: ' + message, 'danger', true);
    };

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
        if ($scope.delay.time === undefined || $scope.delay.time === null) {
            callback({});
            return;
        }

        var delay = {
            time: $scope.delay.time
        };

        $uibModal.open({
            component: 'summaryDialog',
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
                $scope.error(error);
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
     * Observing begins only after config is loaded and observer panel with delayed works are initialized.
     */
    function tryObserve() {
        if ($scope.config.auth.user === '' || $scope.eventListeners.length === 2) {
            return;
        }

        creatorService.observe($scope.config.auth, function (event) {
            $scope.$apply(function () {
                angular.forEach($scope.eventListeners, function (callback) {
                    callback(event);
                });
            });
        });
    }

    $scope.addEventListener = function (callback) {
        $scope.eventListeners.push(callback);
        tryObserve();
    };

    $scope.$watch('config.auth', tryObserve);
});
