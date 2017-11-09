app.service('createService',
    function ($http) {
        var jobs = [];
        var props = [];

        function loadJobs(callback) {
            $http.get("jobs")
                .then(function (response) {
                    jobs = response.data.jobs || [];
                    props = response.data.props || [];
                    callback(jobs, props, response.status, response.statusText);
                }, function (response) {
                    jobs = [];
                    props = [];
                    callback(jobs, props, response.status, response.statusText);
                });
        }

        function createJobs(jobs, callback) {
            $http.post("create", jobs)
                .then(function (response) {
                    var success = response.data.success || 0;
                    var error = response.data.error || "";
                    callback(success, error, response.status, response.statusText);
                }, function (response) {
                    callback(0, "", response.status, response.statusText);
                });
        }

        return {
            loadJobs: loadJobs,
            createJobs: createJobs
        }
    }
);
