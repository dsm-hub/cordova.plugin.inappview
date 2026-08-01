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
   *
   * options.exitUrlPatterns: optional array of URL prefixes (e.g. your payment
   * gateway's return URLs). As soon as a navigation targets a URL starting with
   * one of these prefixes, the native side cancels the navigation BEFORE it
   * loads, closes the view, and fires "closed" with exitUrlMatched: true and
   * the matched URL. Use this instead of pattern-matching "navigationChanged"
   * yourself — that event only fires after a page has already loaded, which is
   * too late/unreliable when the target URL is gated behind the host app's own
   * session (the in-app WebView doesn't share it and may redirect elsewhere
   * first). Do the actual app navigation in your onSuccess handler when you see
   * exitUrlMatched: true.
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
      activateBackButton: options.activateBackButton !== false,
      exitUrlPatterns:    options.exitUrlPatterns     || []
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
      activateBackButton: options.activateBackButton !== false,
      exitUrlPatterns:    options.exitUrlPatterns     || []
    }]);
  },

  hide: function (onSuccess, onError) {
    exec(onSuccess, onError, 'CordovaInAppView', 'hide', []);
  }

};
