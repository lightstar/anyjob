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
                    if (param.type !== 'flag' && param.required) {
                        var value = jobParams[param.name];
                        var isValidParam = value !== undefined && value !== null && value !== '';
                        if (!(validParams[param.name] = isValidParam)) {
                            isAllValid = false;
                        }
                    } else {
                        validParams[param.name] = true;
                    }
                });

                return isAllValid;
            };

            var setDefaultNodes = function () {
                angular.forEach($scope.job.proto.nodes.available, function (node) {
                    if ($scope.job.proto.nodes.default[node]) {
                        $scope.job.nodes[node] = true;
                    }
                });
            };

            var setDefaultParams = function (protoParams, jobParams) {
                angular.forEach(protoParams, function (param) {
                    if (param.default !== undefined) {
                        if (param.type === 'flag') {
                            jobParams[param.name] = !!param.default;
                        } else {
                            jobParams[param.name] = param.default;
                        }
                    }
                });
            };

            $scope.reset = function () {
                $scope.isAnyNode = false;
                $scope.validParams = {};
                $scope.validProps = {};

                $scope.job.nodes = {};
                $scope.job.params = {};
                $scope.job.props = {};

                if ($scope.job.proto !== null) {
                    setDefaultNodes();
                    setDefaultParams($scope.job.proto.params, $scope.job.params);
                    setDefaultParams($scope.config.props, $scope.job.props);
                }

                $scope.validate();
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
