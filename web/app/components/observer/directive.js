app.directive('observer', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            events: '<events'
        },

        link: function($scope) {
            $scope.closed = true;
            $scope.close = function() {
                $scope.closed = true;
            };
            $scope.$watchCollection('events', function() {
                if ($scope.events.length > 0) {
                    $scope.closed = false;
                }
            });
        },

        templateUrl: 'app/components/observer/template.html'
    };
});

app.directive('observerEvent', function ($compile) {
    return {
        restrict: 'A',

        link: function ($scope, element) {
            element.html($scope.config.eventTemplate);
            $compile(element.contents())($scope);
        }
    };
});
