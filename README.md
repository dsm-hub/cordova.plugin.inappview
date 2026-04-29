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
| `url`                | `string`  | —       | **Required.** The URL to load. Must start with `http` or `https`. |
| `title`              | `string`  | `''`    | Text displayed in the top bar.                           |
| `animated`           | `boolean` | `true`  | Whether to use a slide-in animation on open.             |
| `activateBackButton` | `boolean` | `true`  | Whether the hardware back button (Android) closes the view. |

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

| `event`             | Fired when                                    | Includes `url` |
|---------------------|-----------------------------------------------|----------------|
| `navigationChanged` | A page finishes loading (every URL change)    | Yes            |
| `closed`            | The view is dismissed (user or `hide()`)      | Yes — last URL |

**Result object shape**

```js
{
    event: "navigationChanged" | "closed",
    url: "https://..."          // current or last URL
}
```

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

A common use case is detecting a payment redirect URL and closing the view automatically.

```js
cordova.plugins.CordovaInAppView.show(
    {
        url: payUrl,
        title: 'Payment',
        animated: true,
        activateBackButton: true
    },
    (result) => {
        const url = result?.url ?? ''
        const event = result?.event

        if (url.includes('/pages/payment-success')) {
            // Close the webview immediately, then navigate in the app
            cordova.plugins.CordovaInAppView.hide()
            const paymentId = extractPaymentId(url)
            history.push(`/pages/payment-success${paymentId ? `?payment_id=${paymentId}` : ''}`)

        } else if (url.includes('/pages/payment-failed')) {
            cordova.plugins.CordovaInAppView.hide()
            const paymentId = extractPaymentId(url)
            history.push(`/pages/payment-failed${paymentId ? `?payment_id=${paymentId}` : ''}`)

        } else if (event === 'closed') {
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

> **How it works:** The `onSuccess` callback fires every time a page finishes loading. When the payment gateway redirects to a success or failure URL, your callback catches it immediately — no need to wait for the user to close the view manually.

---

## Platform Notes

### iOS

- Uses **WKWebView** with full JavaScript and DOM storage support.
- The top bar includes a centered title and a close button (`✕`) on the right.
- The view is presented modally with `UIModalPresentationFullScreen`.
- Navigation callbacks fire from `WKNavigationDelegate.webView:didFinishNavigation:`.

### Android

- Uses the system **WebView** with JavaScript and DOM storage enabled.
- The WebView runs in a separate `Activity` (`CordovaWebViewImplement`) launched via `startActivityForResult`.
- Navigation callbacks are bridged back to the plugin through a static `UrlChangeListener` interface called from `WebViewClient.onPageFinished`.
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
