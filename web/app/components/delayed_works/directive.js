/**
 * Define 'delayedWorks' directive used to show table with all existing (and available to current user) delayed works.
 * Also delete and update operations are supported.
 * Directive has attributes:
 *   config           - config object.
 *   error            - function used to show error message.
 *   addEventListener - function used to add event listener which will receive new events.
 *                      That listener takes object with event data as argument.
 *   editDelayedWork  - function used to edit choosen delayed work. It takes two arguments: 'delay' with delay data
 *                      object and 'jobs' with array of job data objects.
 *
 * Author:       LightStar
 * Created:      06.01.2019
 * Last update:  11.01.2019
 */

app.directive('delayedWorks', ['$uibModal', 'creatorService', function ($uibModal, creatorService) {
    return {
        restrict: 'A',
        scope: {
            config: '<config',
            error: '&error',
            addEventListener: '&addEventListener',
            editDelayedWork: '&editDelayedWork'
        },

        link: function ($scope) {
            $scope.id = guidGenerator();
            $scope.works = [];
            var worksById = {};

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
             * Prepare delayed work for edit.
             *
             * @param {int} id  - delayed work id.
             * @return {object} object with keys 'delay' (value contains delay data) and 'jobs'
             *                  (value contains array with jobs data)
             */
            $scope.prepareDelayedWorkForEdit = function (id) {
                var work = worksById[id];
                if (work === undefined) {
                    return null;
                }

                var jobs = [];
                angular.forEach(work.jobs, function (job) {
                    var nodes = [];
                    if (job.jobs !== undefined) {
                        angular.forEach(job.jobs, function (job) {
                            nodes.push(job.node);
                        });
                        job = job.jobs[0];
                    } else {
                        nodes.push(job.node);
                    }

                    if (nodes.length === 0) {
                        return;
                    }

                    var proto = $scope.config.jobsByType[job.type];
                    if (!proto) {
                        return;
                    }

                    var jobToEdit = {
                        group: proto.group,
                        proto: proto,
                        nodes: {},
                        params: {},
                        props: {}
                    };

                    angular.forEach(nodes, function (node) {
                        if (proto.nodes.available.indexOf(node) !== -1) {
                            jobToEdit.nodes[node] = true;
                        }
                    });

                    function setParam(param, src, dst) {
                        if (src[param.name] !== undefined) {
                            dst[param.name] = param.type === 'flag' ? !!src[param.name] : src[param.name];
                        }
                    }

                    angular.forEach(proto.params, function (param) {
                        setParam(param, job.params, jobToEdit.params);
                    });

                    angular.forEach(proto.props, function (prop) {
                        setParam(prop, job.props, jobToEdit.props);
                    });

                    jobs.push(jobToEdit);
                });

                var delay = {
                    id: id,
                    time: work.time,
                    summary: work.summary
                };

                return {
                    delay: delay,
                    jobs: jobs
                };
            };

            /**
             * Update delayed works. Soon after calling this method event 'get delayed works' will come.
             */
            function updateDelayedWorks() {
                creatorService.getDelayedWorks(null, requestCompleteCallback);
            }

            /**
             * Preprocess delayed works array.
             * Object 'worksById' is populated here as well as 'delayRestricted' field in every work object.
             */
            function preprocessDelayedWorks() {
                worksById = {};

                angular.forEach($scope.works, function (work) {
                    worksById[work.id] = work;

                    work.delayRestricted = {};
                    angular.forEach(work.jobs, function (job) {
                        if (job.jobs !== undefined) {
                            job = job.jobs[0];
                        }

                        var proto = $scope.config.jobsByType[job.type];
                        if (proto && proto.delayRestricted) {
                            if (proto.delayRestricted['update']) {
                                work.delayRestricted['update'] = true;
                            }
                            if (proto.delayRestricted['delete']) {
                                work.delayRestricted['delete'] = true;
                            }
                        }
                    });
                });
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
                        preprocessDelayedWorks();
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
