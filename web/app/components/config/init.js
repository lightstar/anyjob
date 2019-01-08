/**
 * Load configuration data from server and prepare it for use.
 * That data will be loaded at application start and assigned to 'config' property of root scope.
 * All other components should wait for it to appear there before proceed.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  08.01.2019
 */

app.run(['$http', '$rootScope', function ($http, $rootScope) {
    function init(jobs, props, delayRestricted, observer, auth, error) {
        var config = {
            jobs: jobs,
            props: props,
            delayRestricted: delayRestricted,
            observer: observer,
            auth: auth,
            error: error,
            groups: [],
            jobsByType: {},
            jobsByGroup: {'': []}
        };

        angular.forEach(config.jobs, function (job) {
            if (job.group === undefined || job.group === '') {
                job.group = '';
            }

            if (job.props === undefined) {
                job.props = props;
            }

            if (job.group !== null && config.groups.indexOf(job.group) === -1) {
                config.groups.push(job.group);
                config.jobsByGroup[job.group] = [];
            }

            config.jobsByType[job.type] = job;
            config.jobsByGroup[job.group].push(job);
        });

        $rootScope.config = config;
    }

    init([], [], {}, {eventTemplate: ''}, {user: '', pass: ''}, '');
    $http.get('config')
        .then(function (response) {
            init(response.data.jobs, response.data.props, response.data.delayRestricted, response.data.observer,
                response.data.auth, '');
        }, function (response) {
            init([], [], {}, {eventTemplate: ''}, {user: '', pass: ''},
                serverError(response.data, response.status));
            $rootScope.alert('Error: ' + $rootScope.config.error, 'danger', true);
        });
}]);
