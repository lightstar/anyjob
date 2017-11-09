app.directive('field', function () {
    return {
        restrict: 'A',
        scope: {
            param: '=',
            params: '='
        },

        link: function ($scope, element, attrs) {
            $scope.id = 'id-' + guidGenerator();
            $scope.contentUrl = 'app/shared/field/' + attrs.$normalize($scope.param.type) + '.html';
        },

        template: '<div ng-include="contentUrl"></div>'
    };
});
