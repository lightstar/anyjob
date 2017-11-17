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
            $scope.bigClass = "";

            var delayedEvents = [];
            var timeoutPromise = null;
            var index = 0;

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

                if ($scope.events.length >= 5) {
                    $scope.bigClass = "big";
                }

                timeoutPromise = $timeout(pushEvent, 1000);
            };

            var preprocessEvent = function(event) {
                event.$index = index++;

                switch(event.event) {
                    case 'create':
                    case 'createJobSet':
                        event.class = 'text-primary';
                        break;
                    case 'progress':
                    case 'redirect':
                    case 'progressJobSet':
                        event.class = 'text-info';
                        break;
                    case 'finish':
                        event.class = event.success ? 'text-success' : 'text-danger';
                        break;
                    case 'finishJobSet':
                        event.class = 'text-success';
                        break;
                    default:
                        event.class = '';
                }
            };

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

app.directive('observerEvent', function ($compile) {
    return {
        restrict: 'A',

        link: function ($scope, element) {
            element.html($scope.config.observer.eventTemplate);
            $compile(element.contents())($scope);
        }
    };
});
