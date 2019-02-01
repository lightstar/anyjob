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
 * Last update:  01.02.2019
 */

app.controller('creatorController', ['$scope', '$http', '$compile', '$timeout', '$animate', '$uibModal',
    'creatorService', function ($scope, $http, $compile, $timeout, $animate, $uibModal, creatorService) {
        $scope.jobs = [];
        $scope.delay = {};
        $scope.eventListeners = [];
        $scope.jobsControl = {reset: EMPTY_FN, editDelayedWork: EMPTY_FN};
        $scope.overlayControl = {show: EMPTY_FN, hide: EMPTY_FN};
        $scope.delayedWorksControl = {load: EMPTY_FN};

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
            $scope.alert('Error: ' + message.charAt(0).toLowerCase() + message.slice(1), 'danger', true);
        };

        /**
         * Edit choosen delayed work.
         *
         * @param {object} delay - delay data.
         * @param {array} jobs   - array with job data objects.
         */
        $scope.editDelayedWork = function (delay, jobs) {
            $animate.enabled(false);
            $timeout(function () {
                $animate.enabled(true);
                $scope.goToJobsMode();
            });
            $scope.jobsControl.editDelayedWork(delay, jobs);
        };

        /**
         * Prepare jobs for processing.
         *
         * @param {Function} callback - callback function which will be called with prepared array of job data objects
         *                              as argument.
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
         * @param {Function} callback - callback function which will be called with prepared delay data object as
         *                              argument. If user denies operation, resulting object will be null.
         */
        function prepareDelay(jobs, callback) {
            if (($scope.delay.time === undefined || $scope.delay.time === null) &&
                ($scope.delay.crontab === undefined || $scope.delay.crontab === null || $scope.delay.crontab === '')
            ) {
                callback({});
                return;
            }

            var delay = {
                summary: $scope.delay.summary !== undefined ? $scope.delay.summary : jobs[0].type
            };

            if ($scope.delay.time !== undefined && $scope.delay.time !== null) {
                delay.time = $scope.delay.time;
            } else {
                delay.crontab = $scope.delay.crontab;

                if ($scope.delay.skip) {
                    delay.skip = $scope.delay.skip;
                }

                if ($scope.delay.pause) {
                    delay.pause = 1;
                }
            }

            if ($scope.delay.id !== undefined) {
                delay.id = $scope.delay.id;
            }

            $uibModal.open({
                component: 'summaryDialog',
                resolve: {
                    summary: function () {
                        return delay.summary;
                    }
                }
            }).result.then(function (summary) {
                delay.summary = summary;
                callback(delay);
            }, function () {
                callback(null);
            });
        }

        /**
         * Create or delay jobs.
         */
        $scope.processJobs = function () {
            var callback = function (message, error) {
                if (error !== '') {
                    $scope.error(error);
                } else {
                    $scope.alert(message, 'success');
                    $scope.jobsControl.reset();
                }

                $scope.overlayControl.hide();
            };

            prepareJobs(function (jobs) {
                prepareDelay(jobs, function (delay) {
                    if (delay === null) {
                        return;
                    }

                    $scope.overlayControl.show();

                    if (delay.time !== undefined || delay.crontab !== undefined) {
                        var updateCount = $scope.delay.updateCount || 0;
                        creatorService.delay(delay, jobs, updateCount, function (error) {
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
            if ($scope.config.auth.user === '' || $scope.eventListeners.length !== 2) {
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

        /**
         * Add listener to receive private events.
         *
         * @param {Function} callback - listener function.
         */
        $scope.addEventListener = function (callback) {
            $scope.eventListeners.push(callback);
            tryObserve();
        };

        $scope.$watch('config.auth', tryObserve);

        $scope.$watch('mode', function () {
            if ($scope.mode === CREATOR_MODE_DELAYED_WORKS) {
                $scope.delayedWorksControl.load();
            }
        });
    }]);
