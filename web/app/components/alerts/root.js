/**
 * At application start add special 'alert' function to root scope which will show alert by using special global
 * instance of 'alerts' directive. That directive should be placed somewhere on page with 'control' attribute named as
 * 'rootAlerts'.
 * While directive is not placed, this 'alert' function will just save incoming alerts and show them later.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  08.01.2019
 */

app.run(['$rootScope', function ($rootScope) {
    $rootScope.rootAlerts = {add: null};

    var delayedAlerts = [];

    /**
     * Show alert or save it until later when 'rootAlerts.add' control function will be initialized by directive.
     *
     * @param msg     {string}  alert message.
     * @param type    {string}  alert type as described in https://www.w3schools.com/bootstrap/bootstrap_alerts.asp.
     *                          By default - 'info'.
     * @param persist {boolean} if true, alert will stay infinitely, otherwise - disappear after configured timeout
     *                          (10s by default).
     */
    $rootScope.alert = function (msg, type, persist) {
        if ($rootScope.rootAlerts.add !== null) {
            $rootScope.rootAlerts.add(msg, type, persist);
        } else {
            delayedAlerts.push({msg: msg, type: type, persist: persist});
        }
    };

    $rootScope.$watch('rootAlerts.add', function (add) {
        if (add !== null) {
            angular.forEach(delayedAlerts, function (alert) {
                add(alert.msg, alert.type, alert.persist);
            });
            delayedAlerts.splice(0, delayedAlerts.length);
        }
    });
}]);
