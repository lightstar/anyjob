app.directive('observer', function () {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            events: '<events'
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
