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

            var validateParams = function (protoParams, jobParams, validParams) {
                var isAllValid = true;

                angular.forEach(protoParams, function (param) {
                    if (param.type !== "flag" && param.required) {
                        var value = jobParams[param.name];
                        var isValidParam = value !== undefined && value !== null && value !== "";
                        if (!(validParams[param.name] = isValidParam)) {
                            isAllValid = false;
                        }
                    } else {
                        validParams[param.name] = true;
                    }
                });

                return isAllValid;
            };

            $scope.reset = function () {
                $scope.isAnyNode = false;
                $scope.validParams = {};
                $scope.validProps = {};

                $scope.job.nodes = {};
                $scope.job.params = {};
                $scope.job.props = {};
                if ($scope.job.isValid) {
                    $scope.job.isValid = false;
                    $scope.validChanged();
                }

                if ($scope.job.proto !== null) {
                   validateParams($scope.job.proto.params, $scope.job.params, $scope.validParams);
                   validateParams($scope.config.props, $scope.job.props, $scope.validProps);
                }
            };

            $scope.validate = function () {
                var isValid = true;

                if ($scope.job.proto === null) {
                    isValid = false;
                } else {
                    var isAnyNode = validateNodes();
                    var isParamsAllValid = validateParams($scope.job.proto.params, $scope.job.params,
                        $scope.validParams);
                    var isPropsAllValid = validateParams($scope.config.props, $scope.job.props,
                        $scope.validProps);
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
