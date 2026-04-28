var exec = require('cordova/exec');

module.exports = {

  isAvailable: function (callback) {
    exec(callback, function () { callback(false); }, 'CordovaInAppView', 'isAvailable', []);
  },

  show: function (options, onSuccess, onError) {
    if (!options || !options.url) {
      onError && onError({ error: "url is required" });
      return;
    }
    var opts = {
      url: options.url,
      title: options.title || '',
      animated: options.animated !== false,
      activateBackButton: options.activateBackButton !== false
    };
    exec(onSuccess, onError, 'CordovaInAppView', 'show', [opts]);
  },

  hide: function (onSuccess, onError) {
    exec(onSuccess, onError, 'CordovaInAppView', 'hide', []);
  }

};
