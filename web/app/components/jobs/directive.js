/**
 * Define 'jobs' directive used to show form binded to dynamic job array.
 * Jobs can be freely added and removed here. Also button with some action is provided
 * (for example, to send jobs to server). Directive 'job' is used internally.
 * Directive has attributes:
 *   config  - config object.
 *   control - control object where property 'reset' will be created with function used reset jobs array
 *             to its initial state.
 *   label   - string label for action button.
 *   action  - function called when action button is clicked.
 *   jobs    - model array of objects where result will be stored.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  13.12.2017
 */

app.directive('jobs', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control',
            label: '@label',
            action: '&action',
            jobs: '=result'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.isValid = false;

            /**
             * Add new empty job.
             */
            $scope.add = function () {
                $scope.collapse();
                $scope.jobs.push({isCollapsed: false});
                if ($scope.isValid) {
                    $scope.isValid = false;
                }
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
            };

            /**
             * Validate all jobs. Scope 'isValid' boolean property is set to true if all jobs are valid.
             */
            $scope.validate = function() {
                var isValid = true;

                angular.forEach($scope.jobs, function(job) {
                    if (!job.isValid) {
                        isValid = false;
                    }
                });

                $scope.isValid = isValid;
            };

            /**
             * Reset jobs array to its initial state.
             */
            $scope.control.reset = function() {
                $scope.jobs.splice(0, $scope.jobs.length);
                $scope.add();
            };

            $scope.control.reset();
        },

        templateUrl: 'app/components/jobs/template.html'
    };
});
