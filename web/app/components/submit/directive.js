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
 * Last update:  11.01.2019
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

                if ($scope.delay.isValid !== isDelayValid) {
                    $scope.delay.isValid = isDelayValid;
                }
            }

            /**
             * Initialize delay data.
             */
            function initDelay() {
                $scope.delay.action = $scope.delay.id === undefined ? DELAY_ACTION_CREATE : DELAY_ACTION_UPDATE;
                $scope.delay.isRestricted = !!$scope.config.delayRestricted[$scope.delay.action];
                $scope.delay.isValid = true;

                var initialDate = null;
                if ($scope.delay.time !== undefined && $scope.delay.time !== null) {
                    initialDate = $scope.delay.time;
                }

                $scope.date = dateContext(initialDate, changeDate);
                $scope.date.change();
            }

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
