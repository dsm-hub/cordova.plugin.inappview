var exec = require('cordova/exec');

module.exports = {

  isAvailable: function (callback) {
    exec(callback, function () { callback(false); }, 'CordovaInAppView', 'isAvailable', []);
  },

  /**
   * Opens a remote or local URL in the in-app WebView.
   * Accepted schemes: http://, https://, file://, app://
   *
   * The onSuccess callback fires on every navigation (event: "navigationChanged")
   * and when the view is dismissed (event: "closed"). Both carry a "url" field.
   */
  show: function (options, onSuccess, onError) {
    if (!options || !options.url) {
      onError && onError({ error: 'url is required' });
      return;
    }
    exec(onSuccess, onError, 'CordovaInAppView', 'show', [{
      url:                options.url,
      title:              options.title              || '',
      animated:           options.animated           !== false,
      activateBackButton: options.activateBackButton !== false
    }]);
  },

  /**
   * Renders an HTML string directly inside the in-app WebView.
   * No file I/O, no file:// path, no sandbox issues on iOS.
   *
   * Use this whenever you have a self-contained HTML string to display
   * (e.g. generated SAML/SSO bridge pages).
   *
   * The onSuccess callback fires on every navigation (event: "navigationChanged")
   * and when the view is dismissed (event: "closed"). Both carry a "url" field.
   */
  showHTML: function (options, onSuccess, onError) {
    if (!options || !options.html) {
      onError && onError({ error: 'html is required' });
      return;
    }
    exec(onSuccess, onError, 'CordovaInAppView', 'showHTML', [{
      html:               options.html,
      title:              options.title              || '',
      animated:           options.animated           !== false,
      activateBackButton: options.activateBackButton !== false
    }]);
  },

  hide: function (onSuccess, onError) {
    exec(onSuccess, onError, 'CordovaInAppView', 'hide', []);
  }

};
