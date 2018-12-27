/**
 * Define 'focus' directive used to set focus on some element on 'focus' event. Just apply 'focus' directive to
 * element, assign id attribute to it and call 'focus' factory function from somewhere with that id as argument
 * to set focus on it.
 * See 'delaySummaryDialog' component for example usage.
 *
 * Author:       LightStar
 * Created:      27.12.2018
 * Last update:  27.12.2018
 */

app.directive('focus', function () {
    return function (scope, element, attr) {
        scope.$on('focus', function (event, name) {
            if (name === attr.id) {
                element[0].focus();
            }
        });
    };
});
