/**
 * Define angularjs application routes.
 * For now there is only one destination - creator page.
 *
 * Author:       LightStar
 * Created:      09.11.2017
 * Last update:  12.12.2017
 */

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
