/**
 * Define 'jobs' directive used to show form binded to dynamic job array.
 * Jobs can be freely added and removed here. Also button with some action is provided
 * (for example, to send jobs to server). Directive 'job' is used internally.
 * Directive has attributes:
 *   config  - config object.
 *   control - control object where properties 'reset' and 'editDelayedWork' will be created with functions which
 *             may be called from outside.
 *   action  - function called when action button is clicked.
 *   delay   - model object where delay data will be stored.
 *   jobs    - model array of objects where result will be stored.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  15.01.2019
 */

app.directive('jobs', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control',
            action: '&action',
            delay: '=delay',
            jobs: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.flags = {isValid: false};
            $scope.submitControl = {delayChanged: EMPTY_FN, jobsChanged: EMPTY_FN};

            /**
             * Add new empty job.
             */
            $scope.add = function () {
                $scope.collapse(-1);
                $scope.jobs.push({isCollapsed: false});
                if ($scope.flags.isValid) {
                    $scope.flags.isValid = false;
                }
                $scope.jobsChanged();
            };

            /**
             * Collapse blocks with all jobs except job with provided index.
             *
             * @param {int} exceptIndex - index of job to skip. If null or undefined, nothing is skipped.
             */
            $scope.collapse = function (exceptIndex) {
                angular.forEach($scope.jobs, function (job, index) {
                    if (index !== exceptIndex) {
                        job.isCollapsed = true;
                    }
                });
            };

            /**
             * Remove job with provided index.
             *
             * @param {int} index - index of job to remove.
             */
            $scope.remove = function (index) {
                if ($scope.jobs.length > 1) {
                    $scope.jobs.splice(index, 1);
                }
                $scope.validate();
                $scope.jobsChanged();
            };

            /**
             * Validate all jobs. Scope 'isValid' boolean property is set to true if all jobs are valid.
             */
            $scope.validate = function () {
                var isValid = true;

                angular.forEach($scope.jobs, function (job) {
                    if (!job.isValid) {
                        isValid = false;
                    }
                });

                $scope.flags.isValid = isValid;
            };

            /**
             * Callback called when jobs structure is changed (i.e. some job was added, removed or changed type).
             */
            $scope.jobsChanged = function () {
                $scope.submitControl.jobsChanged($scope.jobs);
            };

            /**
             * Reset jobs array and delay data to their initial state.
             */
            $scope.control.reset = function () {
                delete $scope.delay.id;
                delete $scope.delay.time;
                delete $scope.delay.summary;
                delete $scope.delay.updateCount;
                $scope.submitControl.delayChanged();

                $scope.jobs.splice(0, $scope.jobs.length);
                $scope.add();
            };

            /**
             * Edit choosen delayed work.
             *
             * @param {object} delay - delay data.
             * @param {array} jobs   - array with job data objects.
             */
            $scope.control.editDelayedWork = function (delay, jobs) {
                $scope.delay.id = delay.id;
                $scope.delay.time = delay.time;
                $scope.delay.summary = delay.summary;
                $scope.delay.updateCount = delay.updateCount;

                $scope.jobs.splice(0, $scope.jobs.length);
                Array.prototype.push.apply($scope.jobs, jobs);

                $scope.collapse(0);
                $scope.submitControl.delayChanged();
                $scope.submitControl.jobsChanged($scope.jobs);
            };

            if ($scope.jobs.length === 0) {
                $scope.control.reset();
            }
        },

        templateUrl: 'app/components/jobs/template.html'
    };
});
