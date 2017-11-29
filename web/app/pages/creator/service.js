app.service('creatorService',
    function ($http) {

        function create(jobs, callback) {
            $http.post('create', jobs)
                .then(function (response) {
                    callback(response.data.success === 1 ? '' : (response.data.error || 'unknown error'));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        function observe(auth, callback) {
            getWebSocket(auth).onmessage = function (event) {
                callback(JSON.parse(event.data));
            };
        }

        var socket = null;
        function getWebSocket(auth) {
            if (socket !== null) {
                return socket;
            }

            var socketProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            var socketUrl = socketProtocol + '//' + location.host + '/ws?user=' +
                encodeURIComponent(auth.user) + '&pass=' + encodeURIComponent(auth.pass);
            socket = new ReconnectingWebSocket(socketUrl);

            return socket;
        }

        return {
            create: create,
            observe: observe
        }
    }
);
