/**
 * Global constants.
 *
 * Author:       LightStar
 * Created:      29.11.2017
 * Last update:  06.01.2019
 */

/**
 * Event types for observer.
 */
var EVENT_CREATE = 'create';
var EVENT_FINISH = 'finish';
var EVENT_PROGRESS = 'progress';
var EVENT_REDIRECT = 'redirect';
var EVENT_CLEAN = 'clean';
var EVENT_CREATE_JOBSET = 'createJobSet';
var EVENT_FINISH_JOBSET = 'finishJobSet';
var EVENT_PROGRESS_JOBSET = 'progressJobSet';
var EVENT_CLEAN_JOBSET = 'cleanJobSet';
var EVENT_CREATE_DELAYED_WORK = 'createDelayedWork';
var EVENT_UPDATE_DELAYED_WORK = 'updateDelayedWork';
var EVENT_DELETE_DELAYED_WORK = 'deleteDelayedWork';
var EVENT_PROCESS_DELAYED_WORK = 'processDelayedWork';
var EVENT_GET_DELAYED_WORKS = 'getDelayedWorks';
var EVENT_STATUS = 'status';

/**
 * Minimal delay in milliseconds between appearings of new events in observer.
 */
var OBSERVER_EVENT_MIN_DELAY = 1000;

/**
 * Minimal total count of events for observer panel to take 'big' class.
 */
var OBSERVER_BIG_MIN_EVENTS = 5;

/**
 * Delay action types.
 */
var DELAY_ACTION_CREATE = 'create';
var DELAY_ACTION_UPDATE = 'update';
var DELAY_ACTION_DELETE = 'delete';
var DELAY_ACTION_GET = 'get';

/**
 * Empty function.
 */
var EMPTY_FN = function () {
};

/**
 * Creator page modes.
 */
var CREATOR_MODE_JOBS = 1;
var CREATOR_MODE_DELAYED_WORKS = 2;
