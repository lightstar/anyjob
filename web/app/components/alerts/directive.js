/**
 * Define 'alerts' directive used to show temporary or persistent alerts on page using bootstrap alerts.
 * See https://www.w3schools.com/bootstrap/bootstrap_alerts.asp for details.
 * Directive has 2 attributes:
 *   control - control object where property 'add' will be created with function used to show new alert.
 *             That function takes 3 arguments:
 *               msg - string alert message.
 *               type - string alert type as required by bootstrap.
 *               persist - boolean flag. If true, alert will stay infinitely, otherwise - disappear after timeout.
 *   timeout - timeout in milliseconds to expire non-persistent alerts. By default - 10000 (i.e. 10s).
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  13.12.2017
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

            /**
             * Show alert.
             *
             * @param msg     {string}  alert message.
             * @param type    {string}  alert type as described in
             *                          https://www.w3schools.com/bootstrap/bootstrap_alerts.asp.
             *                          By default - 'info'.
             * @param persist {boolean} if true, alert will stay infinitely, otherwise - disappear after timeout.
             */
            $scope.control.add = function(msg, type, persist) {
                $scope.alerts.push({msg: msg, type: type || 'info', persist: persist || false});
            };

            /**
             * Remove alert from page.
             *
             * @param index {int} index in alerts array.
             */
            $scope.close = function(index) {
                $scope.alerts.splice(index, 1);
            };
        },

        templateUrl: 'app/components/alerts/template.html'
    };
});
