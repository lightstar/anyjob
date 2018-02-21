/**
 * Date and time related functions.
 *
 * Author:       LightStar
 * Created:      21.02.2018
 * Last update:  21.02.2018
 */

/**
 * Object where keys are months and values are numbers of days in corresponding month (in case this year is not leap one).
 */
var DAYS_IN_MONTH = {
    1: 31,
    2: 28,
    3: 31,
    4: 30,
    5: 31,
    6: 30,
    7: 31,
    8: 31,
    9: 30,
    10: 31,
    11: 30,
    12: 31
};

/**
 * Object where keys are months and values are numbers of days in corresponding month (in case this year is leap one).
 */
var DAYS_IN_MONTH_LEAP = {
    1: 31,
    2: 29,
    3: 31,
    4: 30,
    5: 31,
    6: 30,
    7: 31,
    8: 31,
    9: 30,
    10: 31,
    11: 30,
    12: 31
};

/**
 * Parse date and time in provided string trying several formats:
 * 1) 'DD-MM-YYYY HH:MM:SS'
 * 2) 'YYYY-MM-DD HH:MM:SS' (symbols '-', ':' and ' ' are optional here)
 * 3) 'DD-MM-YYY' (time is assumed to be '00:00:00')
 * 4) 'YYYY-MM-DD' (symbol '-' is optional here and time is assumed to be '00:00:00')
 * 5) 'HH:MM:SS' (date is assumed to be current date)
 *
 * @param {string} datetime - input string with date and/or time.
 * @return {Date}  result 'Date' object or null in case of error.
 */
function parseDateTime(datetime) {
    if (datetime === undefined || datetime === null) {
        return null;
    }

    var parsers = [
        function (datetime) {
            var match = datetime.match(/^([0-9]{2})-([0-9]{2})-([0-9]{4})\s+([0-9]{2}):([0-9]{2}):([0-9]{2})$/);
            if (match === null) {
                return null;
            }
            return [parseInt(match[3]), parseInt(match[2]), parseInt(match[1]), parseInt(match[4]),
                parseInt(match[5]), parseInt(match[6])];
        },
        function (datetime) {
            var match = datetime.match(/^([0-9]{4})-?([0-9]{2})-?([0-9]{2})\s*([0-9]{2}):?([0-9]{2}):?([0-9]{2})$/);
            if (match === null) {
                return null;
            }
            return [parseInt(match[1]), parseInt(match[2]), parseInt(match[3]), parseInt(match[4]),
                parseInt(match[5]), parseInt(match[6])];
        },
        function (datetime) {
            var match = datetime.match(/^([0-9]{2})-([0-9]{2})-([0-9]{4})$/);
            if (match === null) {
                return null;
            }
            return [parseInt(match[3]), parseInt(match[2]), parseInt(match[1]), 0, 0, 0];
        },
        function (datetime) {
            var match = datetime.match(/^([0-9]{4})-?([0-9]{2})-?([0-9]{2})$/);
            if (match === null) {
                return null;
            }
            return [parseInt(match[1]), parseInt(match[2]), parseInt(match[3]), 0, 0, 0];
        },
        function (datetime) {
            var match = datetime.match(/^([0-9]{2}):([0-9]{2}):([0-9]{2})$/);
            if (match === null) {
                return null;
            }
            var now = new Date();
            return [now.getFullYear(), now.getMonth() + 1, now.getDate(), parseInt(match[1]),
                parseInt(match[2]), parseInt(match[3])];
        }
    ];

    for (var i = 0; i < parsers.length; i++) {
        var result = parsers[i](datetime);
        if (result !== null) {
            if (!isValidDate(result[2], result[1], result[0]) ||
                !isValidTime(result[3], result[4], result[5])
            ) {
                return null;
            }
            return new Date(result[0], result[1] - 1, result[2], result[3], result[4], result[5]);
        }
    }

    return null;
}

/**
 * Check if provided date is valid.
 *
 * @param {int} day   - day.
 * @param {int} month - month.
 * @param {int} year  - year.
 * @return {boolean} true if date is valid, otherwise - false.
 */
function isValidDate(day, month, year) {
    if (year < 1900 || year > 2100 || month < 1 || month > 12) {
        return false;
    }

    var daysInMonth = isLeapYear(year) ? DAYS_IN_MONTH_LEAP[month] : DAYS_IN_MONTH[month];
    return !(day < 1 || day > daysInMonth);
}

/**
 * Check if provided time is valid.
 *
 * @param {int} hour   - hour.
 * @param {int} minute - minute.
 * @param {int} second - second.
 * @return {boolean} true if time is valid, otherwise - false.
 */
function isValidTime(hour, minute, second) {
    return !(hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59);
}

/**
 * Check if provided year is the leap one.
 *
 * @param {int} year  - year.
 * @return {boolean} true if year is the leap one, otherwise - false.
 */
function isLeapYear(year) {
    return ((year % 4 === 0) && ((year % 100 !== 0) || (year % 400 === 0)));
}
