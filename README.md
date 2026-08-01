# cordova-plugin-inappview

A Cordova plugin that opens URLs in a native in-app WebView with a custom top bar, slide animations, and real-time URL navigation callbacks. Supports iOS (WKWebView) and Android.

---

## Table of Contents

- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [API Reference](#api-reference)
  - [isAvailable](#isavailable)
  - [show](#show)
  - [hide](#hide)
- [Callback Events](#callback-events)
- [Usage Examples](#usage-examples)
  - [Basic Usage](#basic-usage)
  - [Payment Flow with Navigation Tracking](#payment-flow-with-navigation-tracking)
- [Platform Notes](#platform-notes)
- [Project Structure](#project-structure)

---

## Supported Platforms

| Platform | Engine       | Min Version |
|----------|--------------|-------------|
| iOS      | WKWebView    | iOS 11+     |
| Android  | WebView      | API 21+     |

---

## Installation

```bash
cordova plugin add cordova-plugin-inappview
```

Or from a local path:

```bash
cordova plugin add /path/to/cordova-plugin-inappview
```

---

## API Reference

All methods are available under the `cordova.plugins.CordovaInAppView` namespace.

---

### isAvailable

Checks whether the plugin is available on the current platform.

```js
cordova.plugins.CordovaInAppView.isAvailable(callback)
```

| Parameter  | Type       | Description                                 |
|------------|------------|---------------------------------------------|
| `callback` | `Function` | Called with `true` if available, `false` otherwise |

**Example**

```js
cordova.plugins.CordovaInAppView.isAvailable((available) => {
    console.log('Plugin available:', available)
})
```

---

### show

Opens a URL in the in-app WebView. The `onSuccess` callback is invoked **on every navigation** (URL change), allowing you to react to redirects in real time. It is also invoked when the view is closed.

```js
cordova.plugins.CordovaInAppView.show(options, onSuccess, onError)
```

**Options**

| Property             | Type      | Default | Description                                              |
|----------------------|-----------|---------|----------------------------------------------------------|
| `url`                | `string`  | —       | **Required.** The URL to load. Must start with `http://`, `https://`, `file://`, or `app://` (iOS Cordova custom scheme). |
| `title`              | `string`  | `''`    | Text displayed in the top bar.                           |
| `animated`           | `boolean` | `true`  | Whether to use a slide-in animation on open.             |
| `activateBackButton` | `boolean` | `true`  | Whether the hardware back button (Android) closes the view. |
| `exitUrlPatterns`    | `string[]`| `[]`    | URL prefixes to intercept **before** they load (e.g. payment gateway return URLs). See [Callback Events](#callback-events). |

**Callbacks**

| Parameter   | Type       | Description                                                      |
|-------------|------------|------------------------------------------------------------------|
| `onSuccess` | `Function` | Called with a [result object](#callback-events) on each navigation and on close. |
| `onError`   | `Function` | Called with an error object `{ error: string }` on failure.      |

---

### hide

Programmatically closes the in-app WebView.

```js
cordova.plugins.CordovaInAppView.hide(onSuccess, onError)
```

| Parameter   | Type       | Description                                      |
|-------------|------------|--------------------------------------------------|
| `onSuccess` | `Function` | Called with `{ event: "closed" }` after dismissal. |
| `onError`   | `Function` | Called on failure.                               |

**Example**

```js
cordova.plugins.CordovaInAppView.hide(
    () => console.log('View closed'),
    (err) => console.error('Error closing view', err)
)
```

---

## Callback Events

The `onSuccess` callback of `show` receives a result object on every navigation. Check the `event` field to determine what happened.

| `event`             | Fired when                                                        | Includes `url` |
|---------------------|--------------------------------------------------------------------|----------------|
| `navigationChanged` | A page finishes loading (every URL change)                        | Yes            |
| `closed`            | The view is dismissed (user, `hide()`, or an `exitUrlPatterns` match) | Yes — last/matched URL |

**Result object shape**

```js
{
    event: "navigationChanged" | "closed",
    url: "https://...",          // current, last, or matched URL
    exitUrlMatched: true | false // only present on "closed" — true if an exitUrlPatterns prefix triggered the close
}
```

### exitUrlPatterns: closing on a redirect, reliably

`navigationChanged` only fires **after** a page has finished loading. That's too late for something like a payment gateway's return URL if the target page requires a session the in-app WebView doesn't have — the gateway can redirect to it, the private page can bounce again (to a login screen, an error page, whatever), and by the time `navigationChanged` fires, the URL you're matching against may no longer be there. That race is exactly what makes URL-sniffing-on-navigationChanged flaky.

`exitUrlPatterns` avoids the race by matching **before** the navigation is ever allowed to load:

```js
cordova.plugins.CordovaInAppView.show(
    {
        url: payUrl,
        exitUrlPatterns: [
            'https://yourapp.com/pages/payment-success',
            'https://yourapp.com/pages/payment-failed'
        ]
    },
    (result) => {
        if (result.event === 'closed' && result.exitUrlMatched) {
            // result.url is the exact matched redirect URL — the in-app
            // WebView never attempted to load it.
            handlePaymentReturn(result.url)
        } else if (result.event === 'closed') {
            // User dismissed the view without completing payment
        }
    },
    onError
)
```

A match is a simple prefix check (`url.startsWith(pattern)`) performed on the native side, before the request is loaded.

---

## Usage Examples

### Basic Usage

```js
cordova.plugins.CordovaInAppView.show(
    {
        url: 'https://example.com',
        title: 'My Title',
        animated: true,
        activateBackButton: true
    },
    (result) => {
        console.log('Event:', result.event)
        console.log('URL:', result.url)
    },
    (error) => {
        console.error('Error:', error)
    }
)
```

---

### Payment Flow with Navigation Tracking

A common use case is detecting a payment redirect URL and closing the view automatically. Use `exitUrlPatterns` rather than matching on `navigationChanged` — matching against a page that already loaded is too late when the return page is gated behind the app's own session (see [exitUrlPatterns](#exiturlpatterns-closing-on-a-redirect-reliably)).

```js
cordova.plugins.CordovaInAppView.show(
    {
        url: payUrl,
        title: 'Payment',
        animated: true,
        activateBackButton: true,
        exitUrlPatterns: [
            'https://yourapp.com/pages/payment-success',
            'https://yourapp.com/pages/payment-failed'
        ]
    },
    (result) => {
        if (result.event === 'closed' && result.exitUrlMatched) {
            // The gateway's redirect was intercepted before it ever loaded in
            // the in-app view — result.url is the exact matched URL.
            const url = result.url
            const paymentId = extractPaymentId(url)
            const page = url.startsWith('https://yourapp.com/pages/payment-success')
                ? 'payment-success'
                : 'payment-failed'
            history.push(`/pages/${page}${paymentId ? `?payment_id=${paymentId}` : ''}`)

        } else if (result.event === 'closed') {
            // User dismissed the view without completing payment
            setSelectedPackage(null)
        }
    },
    (error) => {
        setSelectedPackage(null)
        console.error('Payment browser error:', error)
    }
)
```

> **How it works:** As soon as a navigation targets a URL starting with one of `exitUrlPatterns`, the native layer cancels the load, closes the view, and calls `onSuccess` with `exitUrlMatched: true` and the matched URL — your app then performs the actual redirect using its own session/router, in the main app WebView, not the in-app one.

---

## Platform Notes

### iOS

- Uses **WKWebView** with full JavaScript and DOM storage support.
- The top bar includes a centered title and a close button (`✕`) on the right.
- The view is presented modally with `UIModalPresentationFullScreen`.
- Navigation callbacks fire from `WKNavigationDelegate.webView:didFinishNavigation:`.
- `exitUrlPatterns` are checked in `webView:decidePolicyForNavigationAction:decisionHandler:`, before the request is allowed to load.

### Android

- Uses the system **WebView** with JavaScript and DOM storage enabled.
- The WebView runs in a separate `Activity` (`CordovaWebViewImplement`) launched via `startActivityForResult`.
- Navigation callbacks are bridged back to the plugin through a static `UrlChangeListener` interface called from `WebViewClient.onPageFinished`.
- `exitUrlPatterns` are checked in `WebViewClient.shouldOverrideUrlLoading`, before the request is allowed to load.
- Non-HTTP(S) URLs (e.g. `intent://`) are forwarded to the system via `Intent.ACTION_VIEW`.
- Slide-in/out animations (`slide_in_right` / `slide_out_left`) are applied when `animated: true`.

---

## Project Structure

```
cordova-plugin-inappview/
├── plugin.xml                          # Plugin manifest
├── package.json
├── www/
│   └── CordovaInAppView.js             # JavaScript API
└── src/
    ├── ios/
    │   ├── CordovaInAppView.h/.m       # CDVPlugin + WKNavigationDelegate
    │   └── WKWebViewController.h/.m    # Modal WebView controller with top bar
    └── android/
        ├── CordovaInAppView.java       # CordovaPlugin + UrlChangeListener bridge
        ├── CordovaWebViewImplement.java # WebView Activity
        ├── SharedConstants.java        # Intent/option key constants
        └── res/
            ├── anim/                   # Slide animations
            └── layout/                 # WebView layout XML
```
