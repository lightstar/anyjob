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

                if (event.event === 'create' || event.event === 'createJobSet') {
                    event.class = 'text-primary';
                } else if (event.event === 'progress' || event.event === 'redirect' || event.event === 'progressJobSet') {
                    event.class = 'text-info';
                } else if (event.event === 'finish') {
                    event.class = event.success ? 'text-success' : 'text-danger';
                } else if (event.event === 'finishJobSet') {
                    event.class = 'text-success';
                } else {
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
