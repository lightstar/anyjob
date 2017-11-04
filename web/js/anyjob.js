var app = angular.module("app", ["ngRoute"]);

app.config(function ($routeProvider) {
    $routeProvider
        .when('/createJob', {
            templateUrl: 'html/createJob.html',
            controller: 'createJob'
        })
        .otherwise({
            redirectTo: '/createJob'
        });
});

app.directive('field', function () {
    return {
        restrict: "A",
        scope: {
            param: "=",
            params: "="
        },

        link: function ($scope, element, attrs) {
            $scope.id = 'id-' + guidGenerator();
            $scope.contentUrl = 'html/field/' + attrs.$normalize($scope.param.type) + '.html';
        },

        template: '<div ng-include="contentUrl"></div>'
    };
});

function guidGenerator() {
    /**
     * @return {string}
     */
    var S4 = function() {
        return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
    };
    return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}

function deleteEmptyFields() {
    for (var i = 0; i < arguments.length; i++) {
        var params = arguments[i];
        for (var name in params) {
            if (params.hasOwnProperty(name) && (params[name] === false || params[name] === "")) {
                delete params[name];
            }
        }
    }
}
