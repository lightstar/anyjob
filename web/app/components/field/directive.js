/**
 * Define 'field' directive used to show form element binded to some job parameter or property.
 * Directive has attributes:
 *   type    - string parameter type, one of: 'flag', 'text', 'textarea', 'datetime', 'combo'.
 *   label   - string parameter label (i.e. description).
 *   name    - string parameter name used as a key in object with all parameters.
 *   options - array of strings with all available values (only for 'combo' type).
 *   change  - function called when parameter value changes.
 *   values  - model object where parameter value should be stored (as values[name]).
 * Used template here is depended on parameter type.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  27.02.2018
 */

app.directive('field', function () {
    return {
        restrict: 'A',
        scope: {
            type: '<',
            label: '<',
            name: '<',
            options: '<',
            change: '&',
            values: '<'
        },

        link: function ($scope, element, attrs) {
            $scope.id = guidGenerator();

            if ($scope.type === 'datetime') {
                $scope.date = {
                    date: parseDateTime($scope.values[$scope.name]),
                    opened: false,
                    options: {
                        maxDate: new Date(2100, 11, 31),
                        minDate: new Date(1900, 0, 1)
                    },
                    open: function () {
                        $scope.date.opened = true;
                    },
                    change: function () {
                        if ($scope.date.date instanceof Date) {
                            $scope.values[$scope.name] = formatDateTime($scope.date.date);
                        } else {
                            $scope.values[$scope.name] = $scope.date.date;
                        }
                        $scope.change();
                    }
                };
            }

            $scope.contentUrl = 'app/components/field/' + attrs.$normalize($scope.type) + '.html';
        },

        template: '<div ng-include="contentUrl"></div>'
    };
});
