var app = angular.module("app", ["ngRoute"]);

app.config(function ($routeProvider) {
    $routeProvider
        .when('/createJob', {
            templateUrl: 'html/createJob.html',
            controller: 'CreateJob'
        })
        .otherwise({
            redirectTo: '/createJob'
        });
});

app.directive('jobParam', function () {
    return {
        restrict: "A",
        scope: {
            param: "="
        },
        link: function ($scope, element, attrs) {
            $scope.contentUrl = 'html/' + attrs.$normalize('param-' + $scope.param.type) + '.html';
        },
        template: '<div ng-include="contentUrl"></div>'
    };
});
