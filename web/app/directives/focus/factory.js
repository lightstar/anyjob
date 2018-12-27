/**
 * Define helper 'focus' factory function used to send 'focus' event to element with some id. To receive that event
 * element must include 'focus' directive in its declaration.
 *
 * Author:       LightStar
 * Created:      27.12.2018
 * Last update:  27.12.2018
 */

app.factory('focus', function ($rootScope, $timeout) {
    return function (id) {
        $timeout(function () {
            $rootScope.$broadcast('focus', id);
        });
    }
});
