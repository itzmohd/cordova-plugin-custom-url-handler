import Foundation
import SafariServices
import WebKit

@objc(CustomUrlLauncher)
class CustomUrlLauncher : CDVPlugin, WKNavigationDelegate {

    // Storage for the deep link URL
    private var startupUrl: String?
    // Variable to hold the configured URL Scheme, read from preferences
    private var customUrlScheme: String = "myapp://"

    /**
     * Called when the application is launched by a URL.
     * This captures the initial deep link URL and reads plugin preferences.
     */
    override func pluginInitialize() {
        super.pluginInitialize()

        // 1. Read the custom URL scheme from plugin settings
        if let configuredScheme = commandDelegate.settings["url_scheme"] as? String {
            // Ensure the scheme ends with "://"
            self.customUrlScheme = configuredScheme.lowercased() + "://"
        }
        
        // 2. Listen for the notification that Cordova fires when it receives a URL
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenURL(_:)), name: Notification.Name.CDVPluginHandleOpenURL, object: nil)

        // 3. Ensure the WKWebView's navigation delegate is set to self to intercept navigation
        if let webView = self.webView as? WKWebView {
            // Assigning self as the navigation delegate allows us to intercept the navigation
            webView.navigationDelegate = self
        }
    }

    @objc func handleOpenURL(_ notification: Notification) {
        if let url = notification.object as? URL {
            // Store the URL from the deep link
            self.startupUrl = url.absoluteString
        }
    }

    /**
     * JavaScript exposed method to retrieve the stored startup URL.
     */
    @objc(getStartupUrl:)
    func getStartupUrl(command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: self.startupUrl)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        self.startupUrl = nil // Consume the URL after retrieval
    }


    // 4. MARK: WKNavigationDelegate Override Logic (WebView Override)

    /**
     * Overrides the WKNavigationDelegate logic to intercept URL loading.
     */
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let urlString = url.absoluteString.lowercased()

        // 1. Check if the URL should be loaded internally (i.e., inside the WebView)
        if isInternalUrl(urlString) {
            // Allow the WebView to handle it (internal navigation or file loading)
            decisionHandler(.allow)
            return
        }

        // 2. If it's not internal, force it to open in the native browser
        if urlString.starts(with: "http") || urlString.starts(with: "https") {
            // Use SFSafariViewController for standard web pages
            if SFSafariViewController.self != nil {
                let safariVC = SFSafariViewController(url: url)
                self.viewController.present(safariVC, animated: true, completion: nil)
            } else {
                // Fallback for older iOS versions
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

        } else if UIApplication.shared.canOpenURL(url) {
            // Handle other custom schemes (mailto, tel, etc.) by opening externally
            UIApplication.shared.open(url, options: [:], completionHandler: nil)

        } else {
            // URL cannot be opened externally (e.g., unknown protocol), allow WebView to handle.
            decisionHandler(.allow)
            return
        }

        // We handled the navigation by opening an external app, so cancel the WebView navigation.
        decisionHandler(.cancel)
    }

    /**
     * Determines if a URL should be considered "internal" and loaded in the WebView.
     */
    private func isInternalUrl(_ url: String) -> Bool {
        // Rule 1: Always allow file:// (local assets)
        if url.starts(with: "file://") {
            return true
        }

        // Rule 2: Always allow the configured custom app scheme (deep links)
        if url.starts(with: self.customUrlScheme) {
            return true
        }

        // By default, treat all other URLs (including external http/https) as external
        return false
    }

    // Clean up observers on deinit
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.CDVPluginHandleOpenURL, object: nil)
    }
}