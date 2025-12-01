#import <Cordova/CDVPlugin.h>
#import <WebKit/WebKit.h>

@interface CustomUrlLauncher : CDVPlugin

- (void)getStartupUrl:(CDVInvokedUrlCommand*)command;

@end