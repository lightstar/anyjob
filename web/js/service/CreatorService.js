app.service('CreatorService',
    function () {
        var jobs = [];

        function loadJobs($http, callback) {
            $http.get("jobs")
                .then(function (response) {
                    jobs = response.data.jobs;
                    callback(jobs);
                });
        }

        return {
            loadJobs: loadJobs
        }
    }
);
