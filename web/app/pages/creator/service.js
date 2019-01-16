/**
 * Define creator service used to create, delay and observe jobs by communicating with server.
 * Also operations with delayed works are supported.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  15.01.2019
 */

app.service('creatorService', ['$http', function ($http) {
        /**
         * Create jobs.
         *
         * @param {array}    jobs     - array of objects with job data to create.
         * @param {function} callback - function which will be called when operation completes. It will receive
         *                              one argument containing string error message or empty string if there were
         *                              no errors.
         */
        function create(jobs, callback) {
            $http.post('create', jobs)
                .then(function (response) {
                    callback(response.data.success === 1 ? '' : (response.data.error || 'unknown error'));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        /**
         * Delay jobs.
         *
         * @param {object}   delay       - object with delay data.
         * @param {array}    jobs        - array of objects with job data to delay.
         * @param {int}      updateCount - current update count of delayed work if it is updated.
         *                                 Ignored if delayed work is created anew.
         * @param {function} callback    - function which will be called when operation completes. It will receive
         *                                 one argument containing string error message or empty string if there were
         *                                 no errors.
         */
        function delay(delay, jobs, updateCount, callback) {
            $http.post('delay', {delay: delay, jobs: jobs, update: updateCount})
                .then(function (response) {
                    callback(response.data.success === 1 ? '' : (response.data.error || 'unknown error'));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        /**
         * Send 'delete delayed work' request.
         *
         * @param {object}   delay       - object with delay data.
         * @param {int}      updateCount - current update count of delayed work.
         * @param {function} callback    - function which will be called when operation completes. It will receive
         *                                 one argument containing string error message or empty string if there were
         *                                 no errors.
         */
        function deleteDelayedWork(delay, updateCount, callback) {
            $http.post('delete_delayed_work', {delay: delay, update: updateCount})
                .then(function (response) {
                    callback(response.data.success === 1 ? '' : (response.data.error || 'unknown error'));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        /**
         * Send 'get delayed works' request. Result will come as 'get delayed works' event in private observer.
         *
         * @param {object}   delay    - object with delay data.
         * @param {function} callback - function which will be called when operation completes. It will receive
         *                              one argument containing string error message or empty string if there were
         *                              no errors.
         */
        function getDelayedWorks(delay, callback) {
            $http.post('get_delayed_works', delay)
                .then(function (response) {
                    callback(response.data.success === 1 ? '' : (response.data.error || 'unknown error'));
                }, function (response) {
                    callback(serverError(response.data, response.status));
                });
        }

        /**
         * Begin observing private events using continuous websocket connection.
         *
         * @param {object}   auth     - object with 'user' and 'pass' string properties containing authentication
         *                              credentials.
         * @param {function} callback - function which will be called for each received event. It will receive
         *                              one argument containing object with event data.
         */
        function observe(auth, callback) {
            getWebSocket(auth).onmessage = function (event) {
                callback(JSON.parse(event.data));
            };
        }

        var socket = null;

        /**
         * Instantiate websocket object or just return previously instantiated one.
         * Library 'ReconnectingWebSocket' object is used which will automatically try to reconnect on any errors.
         *
         * @param {object} auth - object with 'user' and 'pass' string properties containing authentication
         *                        credentials.
         * @return {ReconnectingWebSocket} websocket object.
         */
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
            delay: delay,
            getDelayedWorks: getDelayedWorks,
            deleteDelayedWork: deleteDelayedWork,
            observe: observe
        }
    }]
);
