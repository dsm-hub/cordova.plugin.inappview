package cordova.plugin.inappview;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ImageButton;
import android.widget.ProgressBar;
import android.widget.TextView;

import static cordova.plugin.inappview.SharedConstants.ACTIVATE_BACK_BUTTON_KEY;

@SuppressLint("SetJavaScriptEnabled")
public class CordovaWebViewImplement extends Activity {

    private WebView mWebView;
    private ProgressBar mProgressBar;
    private boolean mShouldBack;
    private String mLastUrl;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(getResources().getIdentifier("cordova_webview", "layout", getPackageName()));

        mWebView = findViewById(getResources().getIdentifier("webView", "id", getPackageName()));
        mProgressBar = findViewById(getResources().getIdentifier("progressBar", "id", getPackageName()));

        TextView toolbarTitle = findViewById(getResources().getIdentifier("toolbarTitle", "id", getPackageName()));
        ImageButton closeButton = findViewById(getResources().getIdentifier("closeButton", "id", getPackageName()));

        String title = getIntent().getStringExtra("TITLE");
        if (title != null && !title.isEmpty()) {
            toolbarTitle.setText(title);
        }

        closeButton.setOnClickListener(v -> finishWithLastUrl());

        WebSettings webSettings = mWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowContentAccess(true);

        String url = getIntent().getStringExtra("URL");
        mShouldBack = getIntent().getBooleanExtra(ACTIVATE_BACK_BUTTON_KEY, true);
        startWebView(url);
    }

    private void startWebView(String url) {
        mWebView.setWebViewClient(new WebViewClient() {

            @Override
            public void onPageFinished(WebView view, String url) {
                mProgressBar.setVisibility(View.GONE);
                mLastUrl = url;
                if (CordovaInAppView.urlChangeListener != null) {
                    CordovaInAppView.urlChangeListener.onUrlChanged(url);
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url == null || url.startsWith("http://") || url.startsWith("https://") || url.startsWith("file://"))
                    return false;
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                    view.getContext().startActivity(intent);
                    return true;
                } catch (Exception e) {
                    return true;
                }
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                mProgressBar.setVisibility(View.VISIBLE);
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                super.onReceivedError(view, request, error);
                mProgressBar.setVisibility(View.GONE);
            }
        });

        // showHTML path — consume the pending HTML string and render it directly.
        // This completely avoids file:// loading and any associated restrictions.
        String pendingHtml = CordovaInAppView.pendingHtmlContent;
        if (pendingHtml != null) {
            CordovaInAppView.pendingHtmlContent = null;
            mWebView.loadDataWithBaseURL("about:blank", pendingHtml, "text/html", "UTF-8", null);
        } else {
            mWebView.loadUrl(url);
        }
    }

    private void finishWithLastUrl() {
        Intent result = new Intent();
        if (mLastUrl != null) {
            result.putExtra("LAST_URL", mLastUrl);
        }
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onBackPressed() {
        if (mShouldBack) {
            finishWithLastUrl();
        }
    }
}
