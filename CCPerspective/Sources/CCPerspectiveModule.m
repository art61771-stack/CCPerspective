#import "CCPerspective.h"

NSNotificationName const CCPerspectiveStateDidChangeNotification = @"com.binglan.ccperspective.statechanged";
static BOOL gEnabled;
static CCPerspectiveLiveLensWindow *gLensWindow;

BOOL CCPerspectiveIsEnabled(void) { return gEnabled; }

static UIWindowScene *ActiveWindowScene(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive)
            return (UIWindowScene *)scene;
    }
    return nil;
}

static void TearDownLens(void) {
    if (!gLensWindow) return;
    [gLensWindow.lensView.glassController invalidate];
    CCPerspectiveLiveLensWindow *window = gLensWindow;
    gLensWindow = nil;
    [UIView animateWithDuration:.2 animations:^{ window.alpha = 0; } completion:^(__unused BOOL done) {
        window.hidden = YES;
        window.rootViewController = nil;
    }];
}

void CCPerspectiveSetEnabled(BOOL enabled) {
    NSCAssert(NSThread.isMainThread, @"CCPerspective state is main-thread confined");
    if (gEnabled == enabled) return;
    gEnabled = enabled;
    [[NSNotificationCenter defaultCenter] postNotificationName:CCPerspectiveStateDidChangeNotification object:nil];
    if (enabled) IBPShowStandaloneLiveLens(); else TearDownLens();
}
void CCPerspectiveToggle(void) { CCPerspectiveSetEnabled(!CCPerspectiveIsEnabled()); }

void IBPShowStandaloneLiveLens(void) {
    if (gLensWindow || !gEnabled) return;
    UIWindowScene *scene = ActiveWindowScene();
    if (!scene) { gEnabled = NO; return; }
    CGRect screen = scene.screen.bounds;
    CCPerspectiveLiveLensWindow *window = [[CCPerspectiveLiveLensWindow alloc] initWithWindowScene:scene];
    window.frame = screen; window.backgroundColor = UIColor.clearColor;
    window.windowLevel = UIWindowLevelAlert + 2.0; window.alpha = 0;
    UIViewController *root = [UIViewController new]; root.view.backgroundColor = UIColor.clearColor;
    window.rootViewController = root;

    CGFloat side = MIN(260.0, CGRectGetWidth(screen) - 32.0);
    CCPerspectiveLiveLensView *lens = [[CCPerspectiveLiveLensView alloc] initWithFrame:CGRectMake((CGRectGetWidth(screen)-side)/2.0, 110.0, side, side)];
    [root.view addSubview:lens]; window.lensView = lens;

    UIView *controls = [[UIView alloc] initWithFrame:CGRectMake(24, CGRectGetHeight(screen)-118, CGRectGetWidth(screen)-48, 58)];
    controls.backgroundColor = [UIColor colorWithWhite:.08 alpha:.82]; controls.layer.cornerRadius = 22;
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(18, 7, CGRectGetWidth(controls.bounds)-82, 44)];
    slider.minimumValue = 1.0; slider.maximumValue = 5.0; slider.value = 2.0;
    [slider addTarget:lens action:@selector(ibp_zoomSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [controls addSubview:slider];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem]; close.frame = CGRectMake(CGRectGetWidth(controls.bounds)-58, 7, 44, 44);
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal]; close.tintColor = UIColor.whiteColor;
    [close addAction:[UIAction actionWithHandler:^(__unused UIAction *a){ CCPerspectiveSetEnabled(NO); }] forControlEvents:UIControlEventTouchUpInside];
    [controls addSubview:close]; [root.view addSubview:controls]; window.controlsView = controls;
    __weak UIView *weakControls=controls;
    lens.controlsVisibilityChanged = ^(BOOL visible){ weakControls.hidden = !visible; };
    gLensWindow = window; window.hidden = NO;
    [lens.glassController setCaptureSourceView:root.view.window ?: window];
    [lens.glassController startLiveRefresh];
    [UIView animateWithDuration:.35 delay:0 usingSpringWithDamping:.82 initialSpringVelocity:0 options:0 animations:^{ window.alpha = 1; } completion:nil];
}

@implementation CCPerspectiveModule
- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController { if (!_contentVC) _contentVC = [CCPerspectiveViewController new]; return _contentVC; }
- (UIViewController *)backgroundViewController { return nil; }
@end
