app.config(function ($routeProvider) {
    $routeProvider
        .when('/creator', {
            templateUrl: 'app/components/creator/template.html',
            controller: 'creatorController'
        })
        .otherwise({
            redirectTo: '/creator'
        });
});
