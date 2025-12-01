var exec = require('cordova/exec');

var CustomUrlLauncher = {
    /**
     * Placeholder function to retrieve the URL that launched the app.
     * This is useful for deep linking logic.
     * @param {function} successCallback - Called with the URL string.
     * @param {function} errorCallback - Called if an error occurs.
     */
    getStartupUrl: function(successCallback, errorCallback) {
        // The native code automatically handles the deep link.
        // This command can be used to explicitly retrieve the URL from the native side.
        exec(successCallback, errorCallback, "CustomUrlLauncher", "getStartupUrl", []);
    }
};

module.exports = CustomUrlLauncher;