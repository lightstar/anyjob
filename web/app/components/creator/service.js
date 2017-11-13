app.service('creatorService',
    function ($http) {
        function create(jobs, callback) {
            $http.post("create", jobs)
                .then(function (response) {
                    callback(response.data.success === 1 ? "" : (response.data.error || "неизвестная ошибка"));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        return {
            create: create
        }
    }
);
