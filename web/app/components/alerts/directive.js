app.directive('alerts', function () {
    return {
        restrict: 'A',
        scope: {
            control: '=',
            timeout: '<'
        },

        link: function ($scope) {
            if (!$scope.timeout) {
                $scope.timeout = 10000;
            }

            $scope.alerts = [];

            $scope.control.add = function(msg, type, persist) {
                $scope.alerts.push({msg: msg, type: type || 'info', persist: persist || false});
            };

            $scope.close = function(index) {
                $scope.alerts.splice(index, 1);
            };
        },

        templateUrl: 'app/shared/alerts/template.html'
    };
});
