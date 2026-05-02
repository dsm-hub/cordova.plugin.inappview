#import <UIKit/UIKit.h>
#import <WebKit/WKWebView.h>

NS_ASSUME_NONNULL_BEGIN

@class CIAVWebViewController;

@protocol CIAVWebViewControllerDelegate <NSObject>
- (void)ciavWebViewControllerDidClose:(CIAVWebViewController *)controller;
@end

@interface CIAVWebViewController : UIViewController

@property (nonatomic, strong) WKWebView               *webView;
@property (nonatomic, strong, nullable) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong, readonly, nullable) NSURL    *url;
@property (nonatomic, copy,   readonly, nullable) NSString *htmlContent;
@property (nonatomic, weak)   id<CIAVWebViewControllerDelegate> delegate;

/** Opens a remote or local URL (http, https, file://, app://). */
- (instancetype)initWithURL:(NSURL *)url
                      title:(NSString *)title
         navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                 uiDelegate:(id<WKUIDelegate>)uiDelegate;

/** Renders an HTML string directly — no file I/O, no sandbox issues. */
- (instancetype)initWithHTML:(NSString *)html
                       title:(NSString *)title
          navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                  uiDelegate:(id<WKUIDelegate>)uiDelegate;

- (void)startActivityIndicator;
- (void)stopActivityIndicator;

@end

NS_ASSUME_NONNULL_END
