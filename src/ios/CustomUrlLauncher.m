#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVUserAgentUtil.h>
#import <SafariServices/SafariServices.h>

@interface CustomUrlLauncher : CDVPlugin <WKUIDelegate>

@property (nonatomic, strong) NSString* startupUrl;
@property (nonatomic, strong) NSString* customUrlScheme;

@end

@implementation CustomUrlLauncher

- (void)pluginInitialize {
    [super pluginInitialize];
    
    // Read the custom URL scheme from plugin settings (case insensitive access)
    NSString *configuredScheme = [self.commandDelegate.settings objectForKey:[@"URL_SCHEME" lowercaseString]];
    
    // Ensure the scheme is set, defaulting if necessary, and append "://"
    if (configuredScheme) {
        self.customUrlScheme = [NSString stringWithFormat:@"%@://", [configuredScheme lowercaseString]];
    } else {
        self.customUrlScheme = @"myapp://";
    }
    
    // Listen for the notification that Cordova fires when it receives a URL
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenURL:) name:CDVPluginHandleOpenURLNotification object:nil];
    
    // Set self as the WKWebView's delegate to intercept navigation requests
    if ([self.webView respondsToSelector:@selector(setUIDelegate:)]) {
        id wkWebView = self.webView;
        [wkWebView setUIDelegate:self];
    }
}

// ---------------------------------------------------
// 1. Deep Link Handling
// ---------------------------------------------------

- (void)handleOpenURL:(NSNotification*)notification {
    NSURL* url = notification.object;
    if (url) {
        self.startupUrl = [url absoluteString];
        NSLog(@"Deep link URL received: %@", self.startupUrl);
    }
}

/**
 * JavaScript exposed method to retrieve the stored startup URL.
 */
- (void)getStartupUrl:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:self.startupUrl];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    self.startupUrl = nil; // Consume the URL after retrieval
}

// ---------------------------------------------------
// 2. WebView Override Logic
// ---------------------------------------------------

/**
 * WKUIDelegate method to intercept links opened in a new window/tab (which includes links with target="_blank" and many external clicks).
 * This ensures external URLs are redirected to the native browser.
 */
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    
    if (!navigationAction.request.URL) {
        return nil;
    }
    
    NSString *urlString = [navigationAction.request.URL absoluteString].lowercaseString;
    
    if ([self isInternalUrl:urlString]) {
        // Internal URL (app scheme or file://), allow normal navigation
        return nil;
    }
    
    // External URL: Open in native browser/external app
    [self openExternalURL:navigationAction.request.URL];
    
    return nil; // Return nil to prevent the WKWebView from creating a new window internally
}

/**
 * Utility function to open a URL externally.
 */
- (void)openExternalURL:(NSURL *)url {
    NSString *urlString = url.absoluteString.lowercaseString;
    
    if ([urlString hasPrefix:@"http"] || [urlString hasPrefix:@"https"]) {
        // Use SFSafariViewController for standard web pages
        if (@available(iOS 9.0, *)) {
            SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:url];
            [self.viewController presentViewController:safariVC animated:YES completion:nil];
        } else {
            // Fallback for older versions
            [[UIApplication sharedApplication] openURL:url];
        }
    } else if ([[UIApplication sharedApplication] canOpenURL:url]) {
        // Handle other custom schemes (mailto, tel, etc.) by opening externally
        [[UIApplication sharedApplication] openURL:url];
    }
}


/**
 * Determines if a URL should be considered "internal" and loaded in the WebView.
 */
- (BOOL)isInternalUrl:(NSString *)url {
    // Rule 1: Always allow file:// (local assets)
    if ([url hasPrefix:@"file://"]) {
        return YES;
    }
    
    // Rule 2: Always allow the configured custom app scheme (deep links)
    if ([url hasPrefix:self.customUrlScheme]) {
        return YES;
    }

    // By default, treat all other URLs (including external http/https) as external
    return NO;
}

// ---------------------------------------------------
// 3. Cleanup
// ---------------------------------------------------

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CDVPluginHandleOpenURLNotification object:nil];
}

@end