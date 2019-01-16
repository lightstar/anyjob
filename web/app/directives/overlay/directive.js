/**
 * Define 'overlay' directive used to show darkened overlay over the page (or specific element) during some operation.
 * That directive doesn't define any html template so all needed html markup and css styling must be done in calling
 * template. The only exception is added 'overlay' class to directive root element.
 * Example of use:
 *     <div class="overlay-wrap">
 *         <div data-overlay data-control="overlayControl"></div>
 *         <!-- some content here -->
 *     </div>
 * It has attributes:
 *   control - control object where properties 'show' and 'hide' will be created with functions which
 *             may be called from outside.
 *
 * Author:       LightStar
 * Created:      12.01.2019
 * Last update:  15.01.2019
 */

app.directive('overlay', function () {
    return {
        restrict: 'A',
        scope: {
            control: '=control'
        },

        link: function ($scope, element) {
            var spinner = new Spinner();
            element.addClass('overlay');

            $scope.control.show = function () {
                element[0].style.display = 'block';
                spinner.spin(element[0]);
            };

            $scope.control.hide = function () {
                element[0].style.display = 'none';
                spinner.stop(element[0]);
            };
        }
    };
});
