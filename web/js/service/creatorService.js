app.service('creatorService',
    function () {
        var jobs = [];
        var props = [];

        function loadJobs($http, callback) {
            $http.get("jobs")
                .then(function (response) {
                    jobs = response.data.jobs;
                    props = response.data.props;
                    callback(jobs, props);
                }, function(response) {
                    console.log("Error: " + response.statusText);
                });
        }

        return {
            loadJobs: loadJobs
        }
    }
);
