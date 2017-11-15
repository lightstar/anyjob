app.config(function ($routeProvider) {
    $routeProvider
        .when('/creator', {
            templateUrl: 'app/pages/creator/template.html',
            controller: 'creatorController'
        })
        .otherwise({
            redirectTo: '/creator'
        });
});
