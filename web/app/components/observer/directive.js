/**
 * Define 'observer' directive used to show observer panel which can receive private events and show them using
 * configured template. This panel is initially hidden and shows when first event is received.
 * User can collapse observer panel but it automatically expands on next event.
 * Directive has attributes:
 *   config  - config object.
 *   control - control object where property 'event' will be created with function used to receive new event.
 *             It takes object with event data as argument.
 *
 * Author:       LightStar
 * Created:      15.11.2017
 * Last update:  13.12.2017
 */

app.directive('observer', function ($timeout) {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            control: '=control'
        },

        link: function ($scope) {
            $scope.events = [];
            $scope.isHidden = true;
            $scope.isCollapsed = true;
            $scope.bigClass = '';

            var delayedEvents = [];
            var timeoutPromise = null;
            var index = 0;

            /**
             * Push one of received events stored in 'delayedEvents' array into scope 'events' array so it shows
             * in the observer panel.
             * That pushing cannot occur faster than with interval defined in 'OBSERVER_EVENT_MIN_DELAY' constant.
             */
            var pushEvent = function () {
                timeoutPromise = null;
                if (delayedEvents.length === 0) {
                    return;
                }

                $scope.events.push(delayedEvents.splice(0, 1)[0]);

                $scope.isHidden = false;
                $timeout(function () {
                    $scope.isCollapsed = false;
                }, 0);

                if ($scope.events.length >=  OBSERVER_BIG_MIN_EVENTS) {
                    $scope.bigClass = 'big';
                }

                timeoutPromise = $timeout(pushEvent, OBSERVER_EVENT_MIN_DELAY);
            };

            /**
             * Preprocess received event data. Inject '$index' and 'class' properties into it.
             *
             * @param {object} event - received event data.
             */
            var preprocessEvent = function(event) {
                event.$index = index++;

                switch(event.event) {
                    case EVENT_CREATE:
                    case EVENT_CREATE_JOBSET:
                        event.class = 'text-primary';
                        break;
                    case EVENT_PROGRESS:
                    case EVENT_REDIRECT:
                    case EVENT_PROGRESS_JOBSET:
                        event.class = 'text-info';
                        break;
                    case EVENT_FINISH:
                        event.class = event.success ? 'text-success' : 'text-danger';
                        break;
                    case EVENT_FINISH_JOBSET:
                        event.class = 'text-success';
                        break;
                    case EVENT_CLEAN:
                    case EVENT_CLEAN_JOBSET:
                        event.class = 'text-danger';
                        break;
                    default:
                        event.class = '';
                }
            };

            /**
             * Receive new event. Events are not shown immediately but with some short interval
             * to improve user experience.
             *
             * @param {object} event - received event data.
             */
            $scope.control.event = function (event) {
                preprocessEvent(event);
                delayedEvents.push(event);
                if (timeoutPromise === null) {
                    pushEvent();
                }
            };
        },

        templateUrl: 'app/components/observer/template.html'
    };
});

/**
 * Helper internal directive 'observer-event' used to dynamically compile configured event template.
 */
app.directive('observerEvent', function ($compile) {
    return {
        restrict: 'A',

        link: function ($scope, element) {
            element.html($scope.config.observer.eventTemplate);
            $compile(element.contents())($scope);
        }
    };
});
