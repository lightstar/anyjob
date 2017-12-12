/**
 * Define 'alerts' directive used to show temporary or persistent alerts on page using bootstrap alerts.
 * See https://www.w3schools.com/bootstrap/bootstrap_alerts.asp for details.
 * Directive have 2 attributes:
 *   control - control object where property 'add' will be created with function used to show new alert.
 *             That function takes 3 arguments:
 *               msg - string alert message.
 *               type - string alert type as required by bootstrap.
 *               persist - boolean flag. If true, alert will stay infinitely, otherwise - disappear after timeout.
 *   timeout - timeout in milliseconds to expire non-persistent alerts. By default - 10000 (i.e. 10s).
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  12.12.2017
 */

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

        templateUrl: 'app/components/alerts/template.html'
    };
});
