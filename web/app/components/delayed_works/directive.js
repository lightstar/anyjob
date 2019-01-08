/**
 * Define 'delayedWorks' directive used to show table with all existing (and available to current user) delayed works.
 * Also delete and update operations are supported.
 * Directive has attributes:
 *   config           - config object.
 *   error            - function used to show error message.
 *   addEventListener - function used to add event listener which will receive new events.
 *                      That listener takes object with event data as argument.
 *
 * Author:       LightStar
 * Created:      06.01.2019
 * Last update:  08.01.2019
 */

app.directive('delayedWorks', ['$uibModal', 'creatorService', function ($uibModal, creatorService) {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            error: '&error',
            addEventListener: '&addEventListener'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.works = [];

            var updateEvents = {};
            angular.forEach([
                EVENT_CREATE_DELAYED_WORK,
                EVENT_UPDATE_DELAYED_WORK,
                EVENT_PROCESS_DELAYED_WORK,
                EVENT_DELETE_DELAYED_WORK
            ], function (event) {
                updateEvents[event] = true;
            });

            /**
             * Called on server request finish.
             *
             * @param {string} error - error text. It will be empty if request finished successfully.
             */
            function requestCompleteCallback(error) {
                if (error !== '') {
                    $scope.error({message: error});
                }
            }

            /**
             * Delete delayed work.
             *
             * @param {int} id - delayed work id.
             */
            $scope.deleteDelayedWork = function (id) {
                $uibModal.open({
                    component: 'confirmDialog'
                }).result.then(function () {
                    creatorService.deleteDelayedWork({id: id}, requestCompleteCallback);
                }, EMPTY_FN);
            };

            /**
             * Edit delayed work.
             *
             * @param {int} id - delayed work id.
             */
            $scope.editDelayedWork = function (id) {
            };

            /**
             * Update delayed works. Soon after calling this method event 'get delayed works' will come.
             */
            function updateDelayedWorks() {
                creatorService.getDelayedWorks(null, requestCompleteCallback);
            }

            /**
             * Receive new event.
             *
             * @param {object} event - received event data.
             */
            function receiveEvent(event) {
                if (updateEvents[event.event]) {
                    updateDelayedWorks();
                }

                switch (event.event) {
                    case EVENT_GET_DELAYED_WORKS:
                        $scope.works = event.works;
                        break;
                    case EVENT_STATUS:
                        break;
                }
            }

            $scope.addEventListener({
                callback: receiveEvent
            });

            updateDelayedWorks();
        },

        templateUrl: 'app/components/delayed_works/template.html'
    };
}]);
