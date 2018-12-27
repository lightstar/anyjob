/**
 * Define 'enter' directive used to perform some action when 'enter' key is pressed inside some element. Just apply
 * 'enter' directive to element and assign some action to it.
 * See 'delaySummaryDialog' component for example usage.
 *
 * Author:       LightStar
 * Created:      27.12.2018
 * Last update:  27.12.2018
 */

app.directive('enter', function () {
    return function (scope, element, attrs) {
        element.bind('keydown keypress', function (event) {
            var key = typeof event.which === "undefined" ? event.keyCode : event.which;
            if (key === 13) {
                scope.$apply(function () {
                    scope.$eval(attrs.enter);
                });
                event.preventDefault();
            }
        });
    };
});
