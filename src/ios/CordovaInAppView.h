#import <Cordova/CDVPlugin.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKUIDelegate.h>
#import "CIAVWebViewController.h"

@interface CordovaInAppView : CDVPlugin <WKNavigationDelegate, WKUIDelegate, CIAVWebViewControllerDelegate>

@property (nonatomic, copy) NSString *callbackId;
@property (nonatomic) BOOL animated;

- (void)isAvailable:(CDVInvokedUrlCommand *)command;
- (void)show:(CDVInvokedUrlCommand *)command;
- (void)showHTML:(CDVInvokedUrlCommand *)command;
- (void)hide:(CDVInvokedUrlCommand *)command;

@end
