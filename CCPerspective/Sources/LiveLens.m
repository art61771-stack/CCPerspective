#import "CCPerspective.h"
#import <AudioToolbox/AudioToolbox.h>
#import <math.h>

@implementation CCPerspectiveLiveLensWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit) return nil;
    BOOL lens = self.lensView && (hit == self.lensView || [hit isDescendantOfView:self.lensView]);
    BOOL controls = self.controlsView && !self.controlsView.hidden && (hit == self.controlsView || [hit isDescendantOfView:self.controlsView]);
    return (lens || controls) ? hit : nil;
}
@end

@implementation CCPerspectiveBackdropView
+ (Class)layerClass { Class cls = NSClassFromString(@"CABackdropLayer"); return cls ?: CALayer.class; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        CALayer *layer = self.layer;
        @try {
            if ([layer respondsToSelector:NSSelectorFromString(@"setWindowServerAware:")]) [layer setValue:@YES forKey:@"windowServerAware"];
            if ([layer respondsToSelector:NSSelectorFromString(@"setLayerUsesCoreImageFilters:")]) [layer setValue:@YES forKey:@"layerUsesCoreImageFilters"];
            if ([layer respondsToSelector:NSSelectorFromString(@"setGroupName:")]) [layer setValue:@"CCPerspective" forKey:@"groupName"];
        } @catch (__unused NSException *e) {}
    } return self;
}
@end

@implementation CCPerspectiveLiveLensView {
    CGPoint _panStart;
    CGFloat _pinchStart;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _zoomFactor = 2.0; _controlsVisible = YES;
        self.backgroundColor = UIColor.clearColor; self.layer.cornerRadius = MIN(frame.size.width,frame.size.height)/2.0;
        self.layer.cornerCurve = kCACornerCurveContinuous; self.clipsToBounds = YES;
        _glassController = [[CCPerspectiveGlassController alloc] initWithTargetView:self style:0];
        _glassController.magnification = _zoomFactor;
        NSArray *gestures = @[
          [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ibp_pan:)],
          [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(ibp_pinch:)],
          [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(ibp_doubleTap:)],
          [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ibp_longPress:)]
        ];
        [(UITapGestureRecognizer *)gestures[2] setNumberOfTapsRequired:2];
        [(UILongPressGestureRecognizer *)gestures[3] setMinimumPressDuration:.45];
        for (UIGestureRecognizer *g in gestures) { g.delegate = self; [self addGestureRecognizer:g]; }
    } return self;
}
- (void)didMoveToWindow { [super didMoveToWindow]; if (self.window) { [_glassController setCaptureSourceView:self.window]; [_glassController startLiveRefresh]; } }
- (void)layoutSubviews { [super layoutSubviews]; self.layer.cornerRadius = MIN(self.bounds.size.width,self.bounds.size.height)/2.0; [_glassController updateLayout]; }
- (void)setZoomFactor:(CGFloat)value { _zoomFactor = MIN(5.0,MAX(1.0,value)); _glassController.magnification = _zoomFactor; [_glassController scheduleRender]; }
- (void)setControlsVisible:(BOOL)value { _controlsVisible=value; if (_controlsVisibilityChanged) _controlsVisibilityChanged(value); }
- (void)ibp_pan:(UIPanGestureRecognizer *)g { if (g.state==UIGestureRecognizerStateBegan) _panStart=self.center; CGPoint d=[g translationInView:self.superview]; self.center=CGPointMake(_panStart.x+d.x,_panStart.y+d.y); if (g.state==UIGestureRecognizerStateEnded||g.state==UIGestureRecognizerStateCancelled) { CGRect safe=UIEdgeInsetsInsetRect(self.superview.bounds,self.superview.safeAreaInsets); CGFloat x=MIN(CGRectGetMaxX(safe)-self.bounds.size.width/2,MAX(CGRectGetMinX(safe)+self.bounds.size.width/2,self.center.x)); CGFloat y=MIN(CGRectGetMaxY(safe)-self.bounds.size.height/2,MAX(CGRectGetMinY(safe)+self.bounds.size.height/2,self.center.y)); [UIView animateWithDuration:.2 animations:^{self.center=CGPointMake(x,y);}]; } [_glassController scheduleRender]; }
- (void)ibp_pinch:(UIPinchGestureRecognizer *)g { if(g.state==UIGestureRecognizerStateBegan)_pinchStart=_zoomFactor; self.zoomFactor=_pinchStart*g.scale; }
- (void)ibp_doubleTap:(UITapGestureRecognizer *)g { if(g.state==UIGestureRecognizerStateRecognized){ self.zoomFactor=(fabs(_zoomFactor-2.0)<.1?3.0:2.0); AudioServicesPlaySystemSound(1519); } }
- (void)ibp_longPress:(UILongPressGestureRecognizer *)g { if(g.state==UIGestureRecognizerStateBegan){ self.controlsVisible=!self.controlsVisible; AudioServicesPlaySystemSound(1519); } }
- (void)ibp_zoomSliderChanged:(UISlider *)slider { self.zoomFactor=slider.value; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { (void)a;(void)b;return YES; }
@end
