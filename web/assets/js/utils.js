function guidGenerator() {
    /**
     * @return {string}
     */
    var S4 = function () {
        return (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1);
    };
    return (S4() + S4() + '-' + S4() + '-' + S4() + '-' + S4() + '-' + S4() + S4() + S4());
}

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

function serverError(data, status) {
    if (typeof(data) === 'object' && data !== null) {
        if (data.message) {
            return data.message;
        } else if (data.error) {
            return data.error;
        } else if (data.exception) {
            return 'exception arised \'' + data.exception + '\'';
        }
    }

    if (typeof(data) === 'string' && data !== '') {
        return data + ' (' + status + ')';
    }

    return 'unknown error (' + status + ')';
}
