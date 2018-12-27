/**
 * Define 'submit' directive used to show form elements responsible for global information about entire job collection
 * and for action button.
 * It has attributes:
 *   config  - config object.
 *   control - control object where properties 'reset' and 'jobsChanged' will be created with functions which may be
 *             called from outside.
 *   flags   - object with shared status flags.
 *   label   - string label with default (non-delay) submit button label.
 *   delay   - model object where delay data will be stored.
 *   action  - function called when action button is clicked.
 *
 * Author:       LightStar
 * Created:      21.12.2018
 * Last update:  27.12.2018
 */

app.directive('submit', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control',
            flags: '<flags',
            label: '<label',
            delay: '=delay',
            action: '&action'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.delay.action = DELAY_ACTION_CREATE;
            $scope.delay.isRestricted = !!$scope.config.delayRestricted[$scope.delay.action];
            $scope.delay.isValid = true;

            var label = $scope.label;

            $scope.date = dateContext($scope.delay.time, function () {
                var isDelayValid = true;
                var date = $scope.date.date;

                if (date instanceof Date) {
                    $scope.delay.time = Math.floor(date.getTime() / 1000);
                } else {
                    $scope.delay.time = null;
                    isDelayValid = date === null;
                }

                $scope.label = date === null ? label : $scope.delay.label;

                if ($scope.delay.isValid !== isDelayValid) {
                    $scope.delay.isValid = isDelayValid;
                }
            });

            /**
             * Reset delay data to its initial state.
             */
            $scope.control.reset = function () {
                $scope.date.date = null;
                $scope.date.change();
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
        },

        templateUrl: 'app/components/submit/template.html'
    };
});
