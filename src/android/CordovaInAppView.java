package cordova.plugin.inappview;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;

import androidx.core.app.ActivityCompat;
import androidx.core.app.ActivityOptionsCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import static cordova.plugin.inappview.SharedConstants.ACTIVATE_BACK_BUTTON_KEY;
import static cordova.plugin.inappview.SharedConstants.ANIMATED_ATTRIBUTE_KEY;
import static cordova.plugin.inappview.SharedConstants.SLIDE_IN_ANIMATION_KEY;
import static cordova.plugin.inappview.SharedConstants.SLIDE_OUT_ANIMATION_KEY;
import static cordova.plugin.inappview.SharedConstants.TITLE_ATTRIBUTE_KEY;
import static cordova.plugin.inappview.SharedConstants.URL_ATTRIBUTE_KEY;

public class CordovaInAppView extends CordovaPlugin {

    public static final int REQUEST_CODE = 1;

    public interface UrlChangeListener {
        void onUrlChanged(String url);
    }

    public static UrlChangeListener urlChangeListener;

    /** HTML string to be rendered directly — set before launching the Activity. */
    public static String pendingHtmlContent = null;

    private CallbackContext callbackContext;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        switch (action) {
            case "isAvailable":
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, true));
                return true;
            case "show": {
                final JSONObject options = args.getJSONObject(0);
                final String url = options.optString(URL_ATTRIBUTE_KEY);
                final String title = options.optString(TITLE_ATTRIBUTE_KEY, "");
                final boolean animated = options.optBoolean(ANIMATED_ATTRIBUTE_KEY, true);
                final boolean activateBackButton = options.optBoolean(ACTIVATE_BACK_BUTTON_KEY, true);

                if (TextUtils.isEmpty(url)) {
                    JSONObject result = new JSONObject();
                    result.put("error", "expected argument 'url' to be a non-empty string.");
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, result));
                    return true;
                }

                try {
                    this.callbackContext = callbackContext;
                    urlChangeListener = changedUrl -> {
                        if (this.callbackContext != null) {
                            try {
                                JSONObject navResult = new JSONObject();
                                navResult.put("event", "navigationChanged");
                                navResult.put("url", changedUrl);
                                PluginResult navPluginResult = new PluginResult(PluginResult.Status.OK, navResult);
                                navPluginResult.setKeepCallback(true);
                                this.callbackContext.sendPluginResult(navPluginResult);
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }
                        }
                    };
                    show(url, title, animated, activateBackButton);
                } catch (Exception ex) {
                    JSONObject result = new JSONObject();
                    result.put("error", ex.getMessage());
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, result));
                }
                return true;
            }
            case "showHTML": {
                final JSONObject options = args.getJSONObject(0);
                final String html = options.optString("html");
                final String title = options.optString(TITLE_ATTRIBUTE_KEY, "");
                final boolean animated = options.optBoolean(ANIMATED_ATTRIBUTE_KEY, true);
                final boolean activateBackButton = options.optBoolean(ACTIVATE_BACK_BUTTON_KEY, true);

                if (TextUtils.isEmpty(html)) {
                    JSONObject result = new JSONObject();
                    result.put("error", "html cannot be empty");
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, result));
                    return true;
                }

                try {
                    this.callbackContext = callbackContext;
                    pendingHtmlContent = html;
                    urlChangeListener = changedUrl -> {
                        if (this.callbackContext != null) {
                            try {
                                JSONObject navResult = new JSONObject();
                                navResult.put("event", "navigationChanged");
                                navResult.put("url", changedUrl);
                                PluginResult navPluginResult = new PluginResult(PluginResult.Status.OK, navResult);
                                navPluginResult.setKeepCallback(true);
                                this.callbackContext.sendPluginResult(navPluginResult);
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }
                        }
                    };
                    // URL is unused — CordovaWebViewImplement will detect pendingHtmlContent
                    show("", title, animated, activateBackButton);
                } catch (Exception ex) {
                    pendingHtmlContent = null;
                    JSONObject result = new JSONObject();
                    result.put("error", ex.getMessage());
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, result));
                }
                return true;
            }
        }
        return false;
    }

    private void show(String url, String title, boolean animated, boolean activateBackButton) {
        Intent intent = new Intent(cordova.getActivity().getApplicationContext(), CordovaWebViewImplement.class);
        intent.putExtra("URL", url);
        intent.putExtra("TITLE", title);
        intent.putExtra(ACTIVATE_BACK_BUTTON_KEY, activateBackButton);

        if (animated) {
            Bundle animBundle = ActivityOptionsCompat.makeCustomAnimation(
                    cordova.getActivity(),
                    getIdentifier(SLIDE_IN_ANIMATION_KEY),
                    getIdentifier(SLIDE_OUT_ANIMATION_KEY)
            ).toBundle();
            cordova.setActivityResultCallback(this);
            ActivityCompat.startActivityForResult(cordova.getActivity(), intent, REQUEST_CODE, animBundle);
        } else {
            cordova.startActivityForResult(this, intent, REQUEST_CODE);
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);
        if (requestCode == REQUEST_CODE && callbackContext != null) {
            urlChangeListener  = null;
            pendingHtmlContent = null;
            JSONObject result = new JSONObject();
            try {
                result.put("event", "closed");
                String lastUrl = (intent != null) ? intent.getStringExtra("LAST_URL") : null;
                result.put("url", lastUrl != null ? lastUrl : "");
            } catch (JSONException e) {
                e.printStackTrace();
            }
            callbackContext.success(result);
            callbackContext = null;
        }
    }

    private int getIdentifier(String name) {
        final Activity activity = cordova.getActivity();
        return activity.getResources().getIdentifier(name, "anim", activity.getPackageName());
    }
}
