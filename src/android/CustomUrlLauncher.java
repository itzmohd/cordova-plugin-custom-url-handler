package cordova.plugin.customurllauncher;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaWebViewClient;
import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;

import android.content.Intent;
import android.net.Uri;
import android.webkit.WebView;
import android.util.Log;

public class CustomUrlLauncher extends CordovaPlugin {

    // Store the last received URL from the Intent
    private String startupUrl = null;
    // Variable to hold the configured URL Scheme, read from preferences
    private String customUrlScheme = "myapp://";

    /**
     * Initializes the plugin, sets up the custom WebViewClient, and captures the initial intent.
     */
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        // 1. Read the custom URL scheme from plugin preferences
        String configuredScheme = preferences.getString("URL_SCHEME", "myapp");
        this.customUrlScheme = configuredScheme + "://";
        Log.d("CustomUrlLauncher", "Initialized with custom scheme: " + this.customUrlScheme);

        // 2. Override WebViewClient to intercept URL loading
        if (webView.getView() instanceof WebView) {
            final WebView standardWebView = (WebView) webView.getView();

            // Set a custom WebViewClient that forces external links to open in the mobile browser
            standardWebView.setWebViewClient(new CustomClient(webView));
        }

        // 3. Handle initial intent for deep linking
        handleIntent(cordova.getActivity().getIntent());
    }

    /**
     * Captures new intents when the app is already running (e.g., another deep link is clicked).
     */
    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    /**
     * Internal logic to check the intent for a URL and store it.
     */
    private void handleIntent(Intent intent) {
        String action = intent.getAction();
        if (Intent.ACTION_VIEW.equals(action)) {
            Uri uri = intent.getData();
            if (uri != null) {
                this.startupUrl = uri.toString();
                Log.d("CustomUrlLauncher", "Deep link URL received: " + this.startupUrl);
            }
        }
    }

    /**
     * Executes the plugin request from JavaScript.
     */
    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if ("getStartupUrl".equals(action)) {
            callbackContext.success(this.startupUrl);
            this.startupUrl = null; // Consume the URL after retrieval
            return true;
        }
        return false;
    }

    /**
     * Custom WebViewClient to override navigation behavior.
     */
    private class CustomClient extends CordovaWebViewClient {

        public CustomClient(CordovaWebView webView) {
            super(webView);
        }

        /**
         * Overrides the default Cordova behavior for URL loading.
         */
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            // Check if the URL should be loaded inside the WebView (internal)
            if (isInternalUrl(url)) {
                // Let the WebView handle it normally.
                return super.shouldOverrideUrlLoading(view, url);
            } else {
                // Force external URLs to open in the native browser or external application.
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    intent.setData(Uri.parse(url));
                    cordova.getActivity().startActivity(intent);
                    return true; // We handled the navigation
                } catch (Exception e) {
                    Log.e("CustomUrlLauncher", "Could not launch external URL: " + url, e);
                    return false; // Fallback to WebView or let Cordova handle it
                }
            }
        }

        /**
         * Determines if a URL should be considered "internal" and loaded in the WebView.
         */
        private boolean isInternalUrl(String url) {
            // Rule 1: Always allow file:// (local assets)
            if (url.startsWith("file://")) {
                return true;
            }

            // Rule 2: Always allow the configured custom app scheme
            if (url.startsWith(customUrlScheme)) {
                return true;
            }

            // By default, treat all other URLs (including external http/https) as external
            return false;
        }
    }
}