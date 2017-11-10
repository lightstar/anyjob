app.run(function ($rootScope) {
    $rootScope.rootAlerts = {add: null};

    var delayedAlerts = [];

    $rootScope.alert = function (msg, type, persist) {
        if ($rootScope.rootAlerts.add !== null) {
            $rootScope.rootAlerts.add(msg, type, persist);
        } else {
            delayedAlerts.push({msg: msg, type: type, persist: persist});
        }
    };

    $rootScope.$watch('rootAlerts.add', function(add) {
        if (add !== null) {
            angular.forEach(delayedAlerts, function(alert) {
                add(alert.msg, alert.type, alert.persist);
            });
            delayedAlerts.splice(0, delayedAlerts.length);
        }
    });
});
