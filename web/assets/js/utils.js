/**
 * Various utility functions.
 *
 * Author:       LightStar
 * Created:      09.11.2017
 * Last update:  19.12.2018
 */

/**
 * Generate globally unique string which can be used for identificators.
 *
 * @return {string} guid.
 */
function guidGenerator() {
    /**
     * @return {string}
     */
    var S4 = function () {
        return (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1);
    };
    return (S4() + S4() + '-' + S4() + '-' + S4() + '-' + S4() + '-' + S4() + S4() + S4());
}

/**
 * Remove all items in provided objects which have false, zero or empty values.
 * This function receives any number of arguments and processes them all.
 */
function deleteEmptyFields() {
    for (var i = 0; i < arguments.length; i++) {
        var params = arguments[i];
        for (var name in params) {
            if (params.hasOwnProperty(name) &&
                (params[name] === null || params[name] === false || params[name] === '' || params[name] === 0)) {
                delete params[name];
            }
        }
    }
}

/**
 * Generate error string by provided server reply data.
 *
 * @param       data   - object or string received from server.
 * @param {int} status - integer status code received from server.
 * @return {string} error string.
 */
function serverError(data, status) {
    if (typeof (data) === 'object' && data !== null) {
        if (data.message) {
            return data.message;
        } else if (data.error) {
            return data.error;
        } else if (data.exception) {
            return 'exception arised \'' + data.exception + '\'';
        }
    }

    if (typeof (data) === 'string' && data !== '') {
        return data + ' (' + status + ')';
    }

    return 'unknown error (' + status + ')';
}
