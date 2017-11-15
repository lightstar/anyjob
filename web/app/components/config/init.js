app.run(function ($http, $rootScope) {
        function init(jobs, props, auth, error) {
            var config = {
                jobs: jobs,
                props: props,
                auth: auth,
                error: error,
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

            $rootScope.config = config;
        }

        init([], [], {user: "", pass: ""}, "");
        $http.get("config")
            .then(function (response) {
                init(response.data.jobs, response.data.props, response.data.auth, "");
            }, function (response) {
                init([], [], {user: "", pass: ""}, serverError(response.data, response.status));
                $rootScope.alert("Error: " + $rootScope.config.error, "danger", true);
            });
    }
);
