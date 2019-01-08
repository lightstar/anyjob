/**
 * Define 'observer' directive used to show observer panel which can receive private events and show them using
 * configured template. This panel is initially hidden and shows when first event is received.
 * User can collapse observer panel but it automatically expands on next event.
 * Directive has attributes:
 *   config           - config object.
 *   addEventListener - function used to add event listener which will receive new events.
 *                      That listener takes object with event data as argument.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  08.01.2019
 */

app.directive('observer', ['$timeout', function ($timeout) {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            addEventListener: '&addEventListener'
        },

        link: function ($scope) {
            $scope.events = [];
            $scope.isHidden = true;
            $scope.isCollapsed = true;
            $scope.bigClass = '';

            var delayedEvents = [];
            var timeoutPromise = null;
            var index = 0;

            var eventClasses = {};
            eventClasses[EVENT_CREATE] = 'text-primary';
            eventClasses[EVENT_CREATE_JOBSET] = 'text-primary';
            eventClasses[EVENT_CREATE_DELAYED_WORK] = 'text-primary';
            eventClasses[EVENT_UPDATE_DELAYED_WORK] = 'text-primary';
            eventClasses[EVENT_PROGRESS] = 'text-info';
            eventClasses[EVENT_REDIRECT] = 'text-info';
            eventClasses[EVENT_PROGRESS_JOBSET] = 'text-info';
            eventClasses[EVENT_PROCESS_DELAYED_WORK] = 'text-info';
            eventClasses[EVENT_FINISH] = function (event) {
                return event.success ? 'text-success' : 'text-danger';
            };
            eventClasses[EVENT_FINISH_JOBSET] = 'text-success';
            eventClasses[EVENT_CLEAN] = 'text-danger';
            eventClasses[EVENT_CLEAN_JOBSET] = 'text-danger';
            eventClasses[EVENT_DELETE_DELAYED_WORK] = 'text-danger';

            var jobEvents = {};
            angular.forEach([EVENT_CREATE, EVENT_PROGRESS, EVENT_REDIRECT, EVENT_FINISH, EVENT_CLEAN],
                function (event) {
                    jobEvents[event] = true;
                });

            /**
             * Push one of received events stored in 'delayedEvents' array into scope 'events' array so it shows
             * in the observer panel.
             * That pushing cannot occur faster than with interval defined in 'OBSERVER_EVENT_MIN_DELAY' constant.
             */
            function pushEvent() {
                timeoutPromise = null;
                if (delayedEvents.length === 0) {
                    return;
                }

                $scope.events.push(delayedEvents.splice(0, 1)[0]);

                $scope.isHidden = false;
                $timeout(function () {
                    $scope.isCollapsed = false;
                }, 0);

                if ($scope.events.length >= OBSERVER_BIG_MIN_EVENTS) {
                    $scope.bigClass = 'big';
                }

                timeoutPromise = $timeout(pushEvent, OBSERVER_EVENT_MIN_DELAY);
            }

            /**
             * Preprocess received event data. Inject '$index', 'job' and 'class' properties into it.
             *
             * @param {object} event - received event data.
             * @return {boolean} process/skip flag. If true, event must be processed, otherwise it must be skipped.
             */
            function preprocessEvent(event) {
                var eventClass = eventClasses[event.event];
                if (eventClass === undefined) {
                    return false;
                }

                event.$index = index++;
                event['class'] = typeof eventClass === 'function' ? eventClass(event) : eventClass;
                if (jobEvents[event.event]) {
                    event.job = $scope.config.jobsByType[event.type];
                }

                return true;
            }

            /**
             * Receive new event. Events are not shown immediately but with some short interval
             * to improve user experience.
             *
             * @param {object} event - received event data.
             */
            function receiveEvent(event) {
                if (!preprocessEvent(event)) {
                    return;
                }

                delayedEvents.push(event);
                if (timeoutPromise === null) {
                    pushEvent();
                }
            }

            $scope.addEventListener({
                callback: receiveEvent
            });
        },

        templateUrl: 'app/components/observer/template.html'
    };
}]);

/**
 * Helper internal directive 'observer-event' used to dynamically compile configured event template.
 */
app.directive('observerEvent', ['$compile', function ($compile) {
    return {
        restrict: 'A',

        link: function ($scope, element) {
            element.html($scope.config.observer.eventTemplate);
            $compile(element.contents())($scope);
        }
    };
}]);
