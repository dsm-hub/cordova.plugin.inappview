#import "CIAVWebViewController.h"
#import <WebKit/WKPreferences.h>
#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKWebpagePreferences.h>

static const CGFloat kCIAVToolbarHeight = 56.0;

@interface CIAVWebViewController ()
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, copy) NSString *pageTitle;
@end

@implementation CIAVWebViewController

- (instancetype)initWithURL:(NSURL *)url
                      title:(NSString *)title
         navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                 uiDelegate:(id<WKUIDelegate>)uiDelegate {
    if (self = [super init]) {
        _url = url;
        _pageTitle = title ?: @"";

        if (@available(iOS 14.0, *)) {
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
            self.webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
        } else {
            WKPreferences *preferences = [[WKPreferences alloc] init];
            preferences.javaScriptEnabled = YES;
            WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
            configuration.preferences = preferences;
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
        }
        self.webView.navigationDelegate = navigationDelegate;
        self.webView.UIDelegate = uiDelegate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildTopBar];

    if (![self.view.subviews containsObject:self.webView]) {
        [self.view addSubview:self.webView];
        [self.webView loadRequest:[NSURLRequest requestWithURL:_url]];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat topInset = 0.0;
    if (@available(iOS 11.0, *)) {
        topInset = self.view.safeAreaInsets.top;
    }

    CGFloat totalBarHeight = kCIAVToolbarHeight + topInset;
    self.topBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, totalBarHeight);

    self.titleLabel.frame = CGRectMake(48, topInset, self.view.bounds.size.width - 96, kCIAVToolbarHeight);
    self.closeButton.frame = CGRectMake(self.view.bounds.size.width - 48, topInset, 48, kCIAVToolbarHeight);
    self.webView.frame = CGRectMake(0, totalBarHeight, self.view.bounds.size.width, self.view.bounds.size.height - totalBarHeight);
}

#pragma mark - Top bar

- (void)buildTopBar {
    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [UIColor whiteColor];
    self.topBar.layer.shadowColor = [UIColor blackColor].CGColor;
    self.topBar.layer.shadowOpacity = 0.1;
    self.topBar.layer.shadowOffset = CGSizeMake(0, 1);
    self.topBar.layer.shadowRadius = 2;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = self.pageTitle;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.titleLabel.textColor = [UIColor blackColor];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:18];
    [self.closeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.accessibilityLabel = @"Close";

    [self.topBar addSubview:self.titleLabel];
    [self.topBar addSubview:self.closeButton];
    [self.view addSubview:self.topBar];
}

- (void)closeButtonTapped {
    if (self.delegate) {
        [self.delegate ciavWebViewControllerDidClose:self];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Activity indicator

- (void)startActivityIndicator {
    if (!self.activityIndicator) {
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [self.activityIndicator setColor:[UIColor orangeColor]];
        [self.view addSubview:self.activityIndicator];
        self.activityIndicator.center = CGPointMake(self.view.frame.size.width / 2,
                                                    self.view.frame.size.height / 2);
    }
    [self.activityIndicator startAnimating];
}

- (void)stopActivityIndicator {
    [self.activityIndicator stopAnimating];
    [self.activityIndicator removeFromSuperview];
    self.activityIndicator = nil;
}

@end
