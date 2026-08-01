#import "CordovaInAppView.h"
#import "CIAVWebViewController.h"
#import <WebKit/WKNavigationAction.h>
#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKWindowFeatures.h>

@interface CordovaInAppView ()
@property (nonatomic, strong) CIAVWebViewController *vc;
@end

@implementation CordovaInAppView

- (void)isAvailable:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)show:(CDVInvokedUrlCommand *)command {
    NSDictionary *options = [command.arguments objectAtIndex:0];

    NSString *urlString = options[@"url"];
    if (urlString == nil || urlString.length == 0) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"url can't be empty"] callbackId:command.callbackId];
        return;
    }
    NSString *lower = [urlString lowercaseString];
    if (!([lower hasPrefix:@"http"] || [lower hasPrefix:@"file://"] || [lower hasPrefix:@"app://"])) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"url must start with http, https, file://, or app://"] callbackId:command.callbackId];
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"invalid url"] callbackId:command.callbackId];
        return;
    }

    NSString *title = options[@"title"] ?: @"";
    self.animated = [[options objectForKey:@"animated"] boolValue];
    self.callbackId = command.callbackId;
    self.exitUrlPatterns = [self stringArrayFromOptions:options key:@"exitUrlPatterns"];

    self.vc = [[CIAVWebViewController alloc] initWithURL:url
                                                   title:title
                                      navigationDelegate:self
                                              uiDelegate:self];
    self.vc.delegate = self;
    self.vc.modalPresentationStyle = UIModalPresentationFullScreen;

    [self.viewController presentViewController:self.vc animated:self.animated completion:nil];

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"opened"}];
    [result setKeepCallback:@YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

- (void)showHTML:(CDVInvokedUrlCommand *)command {
    NSDictionary *options = [command.arguments objectAtIndex:0];

    NSString *html = options[@"html"];
    if (html == nil || html.length == 0) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                 messageAsString:@"html can't be empty"]
                                    callbackId:command.callbackId];
        return;
    }

    NSString *title = options[@"title"] ?: @"";
    self.animated   = [[options objectForKey:@"animated"] boolValue];
    self.callbackId = command.callbackId;
    self.exitUrlPatterns = [self stringArrayFromOptions:options key:@"exitUrlPatterns"];

    self.vc = [[CIAVWebViewController alloc] initWithHTML:html
                                                    title:title
                                       navigationDelegate:self
                                               uiDelegate:self];
    self.vc.delegate               = self;
    self.vc.modalPresentationStyle = UIModalPresentationFullScreen;

    [self.viewController presentViewController:self.vc animated:self.animated completion:nil];

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                            messageAsDictionary:@{@"event": @"opened"}];
    [result setKeepCallback:@YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

- (void)hide:(CDVInvokedUrlCommand *)command {
    if (self.vc != nil) {
        __weak CordovaInAppView *weakSelf = self;
        [self.viewController dismissViewControllerAnimated:self.animated completion:^{
            weakSelf.vc = nil;
        }];
    }
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"closed"}];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

#pragma mark - CIAVWebViewControllerDelegate

- (void)ciavWebViewControllerDidClose:(CIAVWebViewController *)controller {
    NSString *lastUrl = controller.webView.URL.absoluteString ?: @"";
    __weak CordovaInAppView *weakSelf = self;
    [self.viewController dismissViewControllerAnimated:self.animated completion:^{
        weakSelf.vc = nil;
    }];
    if (self.callbackId != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"closed", @"url": lastUrl, @"exitUrlMatched": @NO}];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
        self.callbackId = nil;
    }
    self.exitUrlPatterns = nil;
}

#pragma mark - Exit URL matching

- (NSArray<NSString *> *)stringArrayFromOptions:(NSDictionary *)options key:(NSString *)key {
    id value = options[key];
    if (![value isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<NSString *> *patterns = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if ([item isKindOfClass:[NSString class]] && [(NSString *)item length] > 0) {
            [patterns addObject:item];
        }
    }
    return patterns;
}

- (BOOL)urlMatchesExitPattern:(NSString *)urlString {
    if (urlString == nil) {
        return NO;
    }
    for (NSString *pattern in self.exitUrlPatterns) {
        if ([urlString hasPrefix:pattern]) {
            return YES;
        }
    }
    return NO;
}

/**
 * Closes the view for a matched exit URL without ever letting it load in the
 * in-app WebView. Payment gateway return URLs are often gated behind the host
 * app's own session, which this WebView doesn't share — loading them here can
 * bounce through a login/error page before the app ever sees the target URL.
 * Cancelling the navigation up front and handing the raw URL back to the app
 * removes that race entirely.
 */
- (void)closeForExitUrlMatch:(NSString *)matchedUrl {
    __weak CordovaInAppView *weakSelf = self;
    [self.viewController dismissViewControllerAnimated:self.animated completion:^{
        weakSelf.vc = nil;
    }];
    if (self.callbackId != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"closed", @"url": matchedUrl ?: @"", @"exitUrlMatched": @YES}];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
        self.callbackId = nil;
    }
    self.exitUrlPatterns = nil;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self.vc startActivityIndicator];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.vc stopActivityIndicator];
    if (self.callbackId != nil) {
        NSString *currentUrl = webView.URL.absoluteString ?: @"";
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"navigationChanged", @"url": currentUrl}];
        [result setKeepCallback:@YES];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.vc stopActivityIndicator];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *urlString = navigationAction.request.URL.absoluteString;
    if ([self urlMatchesExitPattern:urlString]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self closeForExitUrlMatch:urlString];
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WKWebView *popup = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    popup.navigationDelegate = self;
    [self.vc.view addSubview:popup];
    [popup loadRequest:[NSURLRequest requestWithURL:navigationAction.request.URL]];
    return popup;
}

@end
