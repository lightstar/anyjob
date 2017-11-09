app.config(function ($routeProvider) {
    $routeProvider
        .when('/createJobs', {
            templateUrl: 'app/components/createJobs/template.html',
            controller: 'createJobs'
        })
        .otherwise({
            redirectTo: '/createJobs'
        });
});
