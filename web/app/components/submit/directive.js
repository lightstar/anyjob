/**
 * Define 'submit' directive used to show form elements responsible for global information about entire job collection
 * and for action button.
 * It has attributes:
 *   config  - config object.
 *   control - control object where properties 'delayChanged' and 'jobsChanged' will be created with functions which
 *             may be called from outside.
 *   flags   - object with shared status flags.
 *   delay   - model object where delay data will be stored.
 *   action  - function called when action button is clicked.
 *
 * Author:       LightStar
 * Created:      21.12.2018
 * Last update:  03.02.2019
 */

app.directive('submit', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control',
            flags: '<flags',
            delay: '=delay',
            action: '&action'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.SCHEDULE_MODE_TIME = SCHEDULE_MODE_TIME;
            $scope.SCHEDULE_MODE_CRONTAB = SCHEDULE_MODE_CRONTAB;

            /**
             * Callback called when current delay datetime is changed.
             */
            function changeDate() {
                var isDelayValid = true;
                var date = $scope.date.date;

                if (date instanceof Date) {
                    $scope.delay.time = formatDateTime(date);
                } else {
                    $scope.delay.time = null;
                    isDelayValid = date === null && $scope.delay.action === DELAY_ACTION_CREATE;
                }

                $scope.label = (date === null && $scope.delay.action === DELAY_ACTION_CREATE) ? 'Create' : 'Delay';
                $scope.delay.isValid = isDelayValid;
            }

            /**
             * Initialize delay data.
             */
            function initDelay() {
                $scope.delay.action = $scope.delay.id === undefined ? DELAY_ACTION_CREATE : DELAY_ACTION_UPDATE;
                $scope.delay.isRestricted = !!$scope.config.delayRestricted[$scope.delay.action];
                $scope.delay.isValid = true;

                if ($scope.delay.crontab !== undefined && $scope.delay.crontab !== null) {
                    $scope.delay.scheduleMode = SCHEDULE_MODE_CRONTAB;
                } else {
                    $scope.delay.scheduleMode = SCHEDULE_MODE_TIME;
                }
                $scope.scheduleModeChanged();
            }

            /**
             * Called when delay schedule mode changes.
             */
            $scope.scheduleModeChanged = function () {
                if ($scope.delay.scheduleMode === SCHEDULE_MODE_TIME) {
                    delete $scope.delay.crontab;
                    delete $scope.delay.skip;
                    delete $scope.delay.pause;

                    var initialDate = $scope.delay.time || null;
                    $scope.date = dateContext(initialDate, changeDate);
                    $scope.date.change();
                } else {
                    delete $scope.delay.time;
                    $scope.validateCrontab();
                    $scope.validateSkip();
                }
            };

            /**
             * Validate crontab specification string after change. It must be non-empty.
             */
            $scope.validateCrontab = function () {
                var isNoCrontab = $scope.delay.crontab === undefined || $scope.delay.crontab === null ||
                    $scope.delay.crontab === '';

                $scope.label = (isNoCrontab && $scope.delay.action === DELAY_ACTION_CREATE) ? 'Create' : 'Delay';
                $scope.isCrontabValid = !isNoCrontab || $scope.delay.action === DELAY_ACTION_CREATE;

                $scope.delay.isValid = $scope.isCrontabValid && $scope.isSkipValid;
            };

            /**
             * Validate skip count after change. It must be empty or positive integer.
             */
            $scope.validateSkip = function () {
                $scope.isSkipValid = $scope.delay.skip === undefined || $scope.delay.skip === null ||
                    $scope.delay.skip === '' || /^[0-9]+$/.test($scope.delay.skip);

                $scope.delay.isValid = $scope.isCrontabValid && $scope.isSkipValid;
            };

            /**
             * Callback called when delay data is changed.
             */
            $scope.control.delayChanged = function () {
                initDelay();
            };

            /**
             * Callback called when jobs structure is changed (i.e. some job was added, removed or changed type).
             *
             * @param {array} jobs - array of objects with job data.
             */
            $scope.control.jobsChanged = function (jobs) {
                var action = $scope.delay.action;
                var isDelayRestricted = !!$scope.config.delayRestricted[action];

                if (!isDelayRestricted) {
                    angular.forEach(jobs, function (job) {
                        if (job.proto && job.proto.delayRestricted && job.proto.delayRestricted[action]) {
                            isDelayRestricted = true;
                        }
                    });
                }

                if ($scope.delay.isRestricted !== isDelayRestricted) {
                    $scope.delay.isRestricted = isDelayRestricted;
                }
            };

            initDelay();
        },

        templateUrl: 'app/components/submit/template.html'
    };
});
