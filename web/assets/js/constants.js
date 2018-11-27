/**
 * Global constants.
 *
 * Author:       LightStar
 * Created:      29.11.2017
 * Last update:  27.11.2018
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
var EVENT_DELAYED_WORKS = 'delayedWorks';

/**
 * Minimal delay in milliseconds between appearings of new events in observer.
 */
var OBSERVER_EVENT_MIN_DELAY = 1000;

/**
 * Minimal total count of events for observer panel to take 'big' class.
 */
var OBSERVER_BIG_MIN_EVENTS = 5;
