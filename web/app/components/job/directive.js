/**
 * Define 'job' directive used to show form elements binded to some job.
 * Directive also injects various default values and does validation.
 * It has attributes:
 *   config        - config object.
 *   job           - model object where result job will be stored.
 *   validChanged  - function called when job validation state changes.
 *                   Validation state is stored in 'isValid' property of job object.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  27.02.2018
 */

app.directive('job', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            job: '=result',
            validChanged: '&validChanged'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();

            /**
             * Validate job nodes. Nodes are valid if they are not empty.
             *
             * @return {boolean} valid flag. If true, nodes are valid.
             */
            var validateNodes = function () {
                var isAnyNode = false;

                angular.forEach($scope.job.nodes, function (value) {
                    if (value) {
                        isAnyNode = true;
                    }
                });

                $scope.isAnyNode = isAnyNode;
                return isAnyNode;
            };

            /**
             * Validate job parameters (or properties). Parameters are valid when all required ones are non-empty
             * ('flag' parameters can't be required).
             *
             * @param {array} protoParams  - array of objects with available parameters from configuration.
             * @param {object} jobParams   - object with current job parameters.
             * @param {object} validParams - object where key is parameter name and value - its valid flag.
             * @param {object} errorParams - object where key is parameter name and value - error message.
             * @return {boolean} valid flag. If true, parameters are valid.
             */
            var validateParams = function (protoParams, jobParams, validParams, errorParams) {
                var isAllValid = true;

                angular.forEach(protoParams, function (param) {
                    var value = jobParams[param.name];

                    if (param.type !== 'flag' && param.required) {
                        var isValidParam = value !== undefined && value !== null && value !== '';
                        if (!(validParams[param.name] = isValidParam)) {
                            errorParams[param.name] = 'Parameter is required';
                            isAllValid = false;
                        } else {
                            delete errorParams[param.name];
                        }
                    } else {
                        validParams[param.name] = true;
                        delete errorParams[param.name];
                    }

                    if (param.type === 'datetime' && validParams[param.name]) {
                        if (value !== undefined && value !== null && value !== '') {
                            if (parseDateTime(value) === null) {
                                validParams[param.name] = false;
                                errorParams[param.name] = 'Incorrect datetime';
                                isAllValid = false;
                            }
                        }
                    }
                });

                return isAllValid;
            };

            /**
             * Inject default nodes into job model. Called when job first initialized or reseted.
             */
            var setDefaultNodes = function () {
                angular.forEach($scope.job.proto.nodes.available, function (node) {
                    if ($scope.job.proto.nodes.default[node]) {
                        $scope.job.nodes[node] = true;
                    }
                });
            };

            /**
             * Inject default parameters (or properties) into job model. Called when job first initialized or reseted.
             *
             * @param {array} protoParams - array of objects with available parameters from configuration.
             * @param {object} jobParams  - object with current job parameters.
             */
            var setDefaultParams = function (protoParams, jobParams) {
                angular.forEach(protoParams, function (param) {
                    if (param.default !== undefined) {
                        if (param.type === 'flag') {
                            jobParams[param.name] = !!param.default; // Used to cast integer value into boolean one.
                        } else {
                            jobParams[param.name] = param.default;
                        }
                    }
                });
            };

            /**
             * Reset job to its initial state (its group and type are preserved).
             */
            $scope.reset = function () {
                $scope.isAnyNode = false;
                $scope.validParams = {};
                $scope.validProps = {};
                $scope.errorParams = {};
                $scope.errorProps = {};

                $scope.job.nodes = {};
                $scope.job.params = {};
                $scope.job.props = {};

                if ($scope.job.proto !== null) {
                    setDefaultNodes();
                    setDefaultParams($scope.job.proto.params, $scope.job.params);
                    setDefaultParams($scope.job.proto.props, $scope.job.props);
                }

                $scope.validate();
            };

            /**
             * Validate job.
             */
            $scope.validate = function () {
                var isValid = true;

                if ($scope.job.proto === null) {
                    isValid = false;
                } else {
                    var isAnyNode = validateNodes();
                    var isParamsAllValid = validateParams($scope.job.proto.params, $scope.job.params,
                        $scope.validParams, $scope.errorParams);
                    var isPropsAllValid = validateParams($scope.job.proto.props, $scope.job.props,
                        $scope.validProps, $scope.errorProps);
                    if (!isAnyNode || !isParamsAllValid || !isPropsAllValid) {
                        isValid = false;
                    }
                }

                if ($scope.job.isValid !== isValid) {
                    $scope.job.isValid = isValid;
                    $scope.validChanged();
                }
            };

            $scope.job.isValid = false;
            $scope.job.group = null;
            $scope.job.proto = null;
            $scope.reset();
        },

        templateUrl: 'app/components/job/template.html'
    };
});
