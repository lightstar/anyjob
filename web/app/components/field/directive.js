app.directive('field', function () {
    return {
        restrict: 'A',
        scope: {
            type: '<',
            label: '<',
            name: '<',
            change: '&',
            values: '<'
        },

        link: function ($scope, element, attrs) {
            $scope.id = guidGenerator();
            $scope.contentUrl = 'app/shared/field/' + attrs.$normalize($scope.type) + '.html';
        },

        template: '<div ng-include="contentUrl"></div>'
    };
});
