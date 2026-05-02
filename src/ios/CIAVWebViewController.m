#import "CIAVWebViewController.h"
#import <WebKit/WebKit.h>

static const CGFloat kCIAVToolbarHeight = 56.0;

@interface CIAVWebViewController ()
@property (nonatomic, strong) UIView    *topBar;
@property (nonatomic, strong) UILabel   *titleLabel;
@property (nonatomic, strong) UIButton  *closeButton;
@property (nonatomic, copy)   NSString  *pageTitle;
@end

@implementation CIAVWebViewController

// ─── Shared WebView setup ─────────────────────────────────────────────────────

- (void)setupWebViewWithNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                                uiDelegate:(id<WKUIDelegate>)uiDelegate {
    // Always build WKWebViewConfiguration BEFORE creating WKWebView.
    // Mutating config.defaultWebpagePreferences after init affects a consumed copy.
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    if (@available(iOS 14.0, *)) {
        config.defaultWebpagePreferences.allowsContentJavaScript = YES;
    } else {
        WKPreferences *prefs = [[WKPreferences alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        prefs.javaScriptEnabled = YES;
#pragma clang diagnostic pop
        config.preferences = prefs;
    }
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = navigationDelegate;
    self.webView.UIDelegate         = uiDelegate;
}

// ─── Init ─────────────────────────────────────────────────────────────────────

/** Opens a URL (http/https/file:///app://). */
- (instancetype)initWithURL:(NSURL *)url
                      title:(NSString *)title
         navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                 uiDelegate:(id<WKUIDelegate>)uiDelegate {
    if (!(self = [super init])) { return nil; }
    _url       = url;
    _pageTitle = title ?: @"";
    [self setupWebViewWithNavigationDelegate:navigationDelegate uiDelegate:uiDelegate];
    return self;
}

/**
 * Renders an HTML string directly inside WKWebView.
 * No file I/O, no file:// paths, no WKWebView sandbox extension needed.
 * This is the correct approach for generated/self-contained HTML pages.
 */
- (instancetype)initWithHTML:(NSString *)html
                       title:(NSString *)title
          navigationDelegate:(id<WKNavigationDelegate>)navigationDelegate
                  uiDelegate:(id<WKUIDelegate>)uiDelegate {
    if (!(self = [super init])) { return nil; }
    _htmlContent = [html copy];
    _pageTitle   = title ?: @"";
    [self setupWebViewWithNavigationDelegate:navigationDelegate uiDelegate:uiDelegate];
    return self;
}

// ─── Lifecycle ────────────────────────────────────────────────────────────────

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildTopBar];
    [self.view addSubview:self.webView];

    if (_htmlContent) {
        // HTML string path — no file system involved, no sandbox extension needed.
        [self.webView loadHTMLString:_htmlContent baseURL:nil];
    } else {
        [self loadURL:_url];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat topInset = 0.0;
    if (@available(iOS 11.0, *)) {
        topInset = self.view.safeAreaInsets.top;
    }

    CGFloat totalBarHeight = kCIAVToolbarHeight + topInset;
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;

    self.topBar.frame     = CGRectMake(0, 0, W, totalBarHeight);
    // Title: centred, with room for the close button on the right
    self.titleLabel.frame = CGRectMake(48, topInset, W - 96, kCIAVToolbarHeight);
    // Close button: right edge, fully inside the bar (use W-48 as origin so the
    // 48-pt button ends exactly at the right edge)
    self.closeButton.frame = CGRectMake(W - 48, topInset, 48, kCIAVToolbarHeight);
    self.webView.frame    = CGRectMake(0, totalBarHeight, W, H - totalBarHeight);

    // Keep the activity indicator centred if it is visible
    if (self.activityIndicator && !self.activityIndicator.isHidden) {
        self.activityIndicator.center = CGPointMake(W / 2.0, H / 2.0);
    }
}

// ─── URL Loading ─────────────────────────────────────────────────────────────
//
// Routing logic:
//
//  http / https          → loadRequest  (standard remote page)
//
//  app://localhost/…     → resolved to file:// inside bundle's www folder,
//                          then falls through to file:// handling below.
//
//  file:// inside bundle → loadFileURL:allowingReadAccessToURL:
//                          (WebKit's web process is always granted read access
//                          to the app bundle; this is the fast, correct path.)
//
//  file:// outside bundle→ The WKWebView web-process sandbox CANNOT be granted
//                          a sandbox extension for the app's own container
//                          (Caches, tmp, Documents …). loadFileURL: will be
//                          silently rejected with:
//                            "url is not inside resource directory url"
//                          Fix: read the bytes in the *app* process (which has
//                          full container access) and hand the HTML string to
//                          loadHTMLString:baseURL:. No sandbox extension needed.
//
- (void)loadURL:(NSURL *)url {
    if (!url) {
        NSLog(@"[CIAVWebViewController] loadURL called with nil URL");
        return;
    }

    NSString *scheme = url.scheme.lowercaseString;

    // ── 1. Remote HTTP(S) ─────────────────────────────────────────────────────
    if ([scheme hasPrefix:@"http"]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url
                                                 cachePolicy:NSURLRequestUseProtocolCachePolicy
                                             timeoutInterval:30];
        [self.webView loadRequest:request];
        return;
    }

    // ── 2. app:// → resolve to file:// inside the bundle ─────────────────────
    if ([scheme isEqualToString:@"app"]) {
        NSString *wwwRoot = [[NSBundle mainBundle] pathForResource:@"www" ofType:nil];
        if (!wwwRoot) {
            NSLog(@"[CIAVWebViewController] Cannot resolve app:// — www bundle folder not found");
            return;
        }
        // Stitch the path component from the app:// URL onto the www root.
        // url.path already strips the leading slash correctly.
        NSString *filePath = [wwwRoot stringByAppendingPathComponent:url.path];

        NSURLComponents *c = [NSURLComponents new];
        c.scheme   = @"file";
        c.host     = @"";      // empty string, not nil — avoids "///" vs "//" ambiguity
        c.path     = filePath;
        c.fragment = url.fragment;
        url    = c.URL;
        scheme = @"file";
        // fall through ↓
    }

    // ── 3. file:// ────────────────────────────────────────────────────────────
    if ([scheme isEqualToString:@"file"]) {
        // Resolve symlinks so that /var/… and /private/var/… compare equal.
        NSString *canonicalPath = url.URLByResolvingSymlinksInPath.path;
        NSString *wwwRoot       = [[NSBundle mainBundle] pathForResource:@"www" ofType:nil];

        if (wwwRoot && [canonicalPath hasPrefix:wwwRoot]) {
            // ── 3a. Inside the app bundle (www) ──────────────────────────────
            NSURL *fileURL    = [NSURL fileURLWithPath:canonicalPath];
            NSURL *accessURL  = [NSURL fileURLWithPath:wwwRoot isDirectory:YES];
            [self.webView loadFileURL:fileURL allowingReadAccessToURL:accessURL];

        } else {
            // ── 3b. Outside the bundle (Caches, tmp, Documents …) ────────────
            //
            // WKWebView's web process lives in a tight sandbox and iOS refuses
            // to issue a sandbox extension for the app container. Using
            // loadFileURL:allowingReadAccessToURL: with a container path
            // silently fails. Instead:
            //   1. Read the file content in the app process (full access).
            //   2. Push it to WKWebView as an HTML string.
            //   3. Set baseURL to the file's parent directory so that any
            //      relative sub-resources (images, CSS) still resolve — though
            //      for our generated bridge pages there are none.
            //
            NSError  *readError = nil;
            NSURL    *fileURL   = [NSURL fileURLWithPath:canonicalPath];
            NSString *html      = [NSString stringWithContentsOfURL:fileURL
                                                           encoding:NSUTF8StringEncoding
                                                              error:&readError];
            if (html) {
                NSURL *baseURL = [fileURL URLByDeletingLastPathComponent];
                [self.webView loadHTMLString:html baseURL:baseURL];
            } else {
                NSLog(@"[CIAVWebViewController] Failed to read file at %@: %@",
                      canonicalPath, readError.localizedDescription);
            }
        }
        return;
    }

    NSLog(@"[CIAVWebViewController] Unsupported URL scheme '%@' in URL: %@", scheme, url);
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

- (void)buildTopBar {
    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor          = UIColor.whiteColor;
    self.topBar.layer.shadowColor        = UIColor.blackColor.CGColor;
    self.topBar.layer.shadowOpacity      = 0.10f;
    self.topBar.layer.shadowOffset       = CGSizeMake(0, 1);
    self.topBar.layer.shadowRadius       = 2;
    self.topBar.layer.masksToBounds      = NO;

    self.titleLabel                      = [[UILabel alloc] init];
    self.titleLabel.text                 = self.pageTitle;
    self.titleLabel.textAlignment        = NSTextAlignmentCenter;
    self.titleLabel.font                 = [UIFont boldSystemFontOfSize:17];
    self.titleLabel.textColor            = UIColor.blackColor;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor   = 0.8;

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font     = [UIFont systemFontOfSize:18];
    [self.closeButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    self.closeButton.accessibilityLabel  = @"Close";
    [self.closeButton addTarget:self
                         action:@selector(closeButtonTapped)
               forControlEvents:UIControlEventTouchUpInside];

    [self.topBar addSubview:self.titleLabel];
    [self.topBar addSubview:self.closeButton];
    [self.view addSubview:self.topBar];
}

- (void)closeButtonTapped {
    if ([self.delegate respondsToSelector:@selector(ciavWebViewControllerDidClose:)]) {
        [self.delegate ciavWebViewControllerDidClose:self];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// ─── Activity Indicator ───────────────────────────────────────────────────────

- (void)startActivityIndicator {
    if (!self.activityIndicator) {
        if (@available(iOS 13.0, *)) {
            self.activityIndicator = [[UIActivityIndicatorView alloc]
                                      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            self.activityIndicator = [[UIActivityIndicatorView alloc]
                                      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
#pragma clang diagnostic pop
        }
        self.activityIndicator.color = [UIColor colorWithRed:0.82 green:0.07 blue:0.31 alpha:1]; // QIIB red
        // Center will be updated in viewDidLayoutSubviews; set a provisional value now.
        self.activityIndicator.center = CGPointMake(self.view.bounds.size.width  / 2.0,
                                                    self.view.bounds.size.height / 2.0);
        [self.view addSubview:self.activityIndicator];
        [self.view bringSubviewToFront:self.activityIndicator];
    }
    [self.activityIndicator startAnimating];
}

- (void)stopActivityIndicator {
    [self.activityIndicator stopAnimating];
    [self.activityIndicator removeFromSuperview];
    self.activityIndicator = nil;
}

@end
