app.service('createService',
    function ($http) {
        function create(jobs, callback) {
            $http.post("create", jobs)
                .then(function (response) {
                    callback(response.data.success || 0, response.data.error || "",
                        response.status, response.statusText);
                }, function (response) {
                    callback(0, "", response.status, response.statusText);
                });
        }

        return {
            create: create
        }
    }
);
