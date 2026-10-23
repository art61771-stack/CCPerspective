#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN
extern NSNotificationName const CCPerspectiveStateDidChangeNotification;
BOOL CCPerspectiveIsEnabled(void);
void CCPerspectiveSetEnabled(BOOL enabled);
void CCPerspectiveToggle(void);
void IBPShowStandaloneLiveLens(void);

@interface CCPerspectiveModule : NSObject <CCUIContentModule>
@property(nonatomic,strong) UIViewController<CCUIContentModuleContentViewController> *contentVC;
- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController;
- (UIViewController *)backgroundViewController;
@end

@interface CCUIButtonModuleViewController : UIViewController
@property(nonatomic,getter=isSelected) BOOL selected;
@property(nonatomic,strong) UIImage *glyphImage;
@property(nonatomic,strong) UIImage *selectedGlyphImage;
@property(nonatomic,strong) UIColor *glyphColor;
@property(nonatomic,strong) UIColor *selectedGlyphColor;
@end
@interface CCPerspectiveViewController : CCUIButtonModuleViewController <CCUIContentModuleContentViewController>
- (BOOL)providesOwnPlatter;
- (CGFloat)preferredExpandedContentHeight;
- (CGFloat)preferredExpandedContentWidth;
- (BOOL)shouldBeginTransitionToExpandedContentModule;
- (void)buttonTapped:(id)sender forEvent:(UIEvent *)event;
@end

@class CCPerspectiveLiveLensView;
@interface CCPerspectiveLiveLensWindow : UIWindow
@property(nonatomic,weak) CCPerspectiveLiveLensView *lensView;
@property(nonatomic,weak) UIView *controlsView;
@end

@interface CCPerspectiveBackdropView : UIView @end

@interface CCPerspectiveZeroCopyBridge : NSObject
@property(nonatomic,readonly,nullable) id<MTLTexture> texture;
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (BOOL)setupBufferWithWidth:(size_t)width height:(size_t)height;
- (nullable id<MTLTexture>)renderWithActions:(void (^)(CGContextRef context))actions;
- (void)invalidate;
@end

@class CCPerspectiveGlassController;
@interface CCPerspectiveGlassDisplayLinkProxy : NSObject
- (instancetype)initWithTarget:(CCPerspectiveGlassController *)target;
- (void)tick:(CADisplayLink *)link;
@end

@interface CCPerspectiveGlassController : NSObject
@property(nonatomic) CGFloat magnification;
@property(nonatomic) BOOL continuousRefreshEnabled;
@property(nonatomic) BOOL capturesFromWindow;
@property(nonatomic) NSInteger targetFramesPerSecond;
- (instancetype)initWithTargetView:(UIView *)view;
- (instancetype)initWithTargetView:(UIView *)view style:(NSInteger)style;
- (void)setCaptureSourceView:(nullable UIView *)source;
- (void)scheduleRender;
- (void)startLiveRefresh;
- (void)bl_liveDisplayLinkTick:(CADisplayLink *)link;
- (void)updateLayout;
- (void)refresh;
- (void)captureBackdrop;
- (void)blurBackgroundTextureIfNeeded;
- (void)updateUniforms;
- (void)renderFrame;
- (void)compileShaders;
- (void)invalidate;
@end

@interface CCPerspectiveLiveLensView : UIView <UIGestureRecognizerDelegate>
@property(nonatomic) CGFloat zoomFactor;
@property(nonatomic) BOOL controlsVisible;
@property(nonatomic,copy,nullable) void (^controlsVisibilityChanged)(BOOL visible);
@property(nonatomic,strong) CCPerspectiveGlassController *glassController;
@end
NS_ASSUME_NONNULL_END
