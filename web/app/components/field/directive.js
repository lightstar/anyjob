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
            $scope.contentUrl = 'app/components/field/' + attrs.$normalize($scope.type) + '.html';
        },

        template: '<div ng-include="contentUrl"></div>'
    };
});
