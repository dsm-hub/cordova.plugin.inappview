#import <UIKit/UIKit.h>
#import <WebKit/WKWebView.h>

NS_ASSUME_NONNULL_BEGIN

@class CIAVWebViewController;

@protocol CIAVWebViewControllerDelegate <NSObject>
- (void)ciavWebViewControllerDidClose:(CIAVWebViewController *)controller;
@end

@interface CIAVWebViewController : UIViewController

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic) id<WKNavigationDelegate> navigationDelegate;
@property (nonatomic, weak) id<CIAVWebViewControllerDelegate> delegate;

- (instancetype)initWithURL:(NSURL *)url
                      title:(NSString *)title
         navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                 uiDelegate:(id<WKUIDelegate>)uiDelegate;

- (void)startActivityIndicator;
- (void)stopActivityIndicator;

@end

NS_ASSUME_NONNULL_END
