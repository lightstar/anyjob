app.service('configService',
    function ($http) {
        var config;
        initConfig([], []);

        function initConfig(jobs, props) {
            config = {
                jobs: jobs,
                props: props,
                groups: [],
                jobsByGroup: {null: []}
            };

            angular.forEach(config.jobs, function (job) {
                if (job.group === undefined || job.group === "") {
                    job.group = null;
                }

                if (job.group !== null && config.groups.indexOf(job.group) === -1) {
                    config.groups.push(job.group);
                    config.jobsByGroup[job.group] = [];
                }

                config.jobsByGroup[job.group].push(job);
            });
        }

        function load(callback) {
            $http.get("config")
                .then(function (response) {
                    initConfig(response.data.jobs || [], response.data.props || []);
                    callback(config, response.status, response.statusText);
                }, function (response) {
                    initConfig([], []);
                    callback(config, response.status, response.statusText);
                });
        }

        return {
            load: load
        }
    }
);
