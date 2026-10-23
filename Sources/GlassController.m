#import "CCPerspective.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <CoreVideo/CoreVideo.h>
#import <simd/simd.h>
#import <dispatch/dispatch.h>
#import <string.h>

@interface CCPerspectiveGlassController ()
- (void)compileShaders;
@end

@implementation CCPerspectiveGlassDisplayLinkProxy { __weak CCPerspectiveGlassController *_target; }
- (instancetype)initWithTarget:(CCPerspectiveGlassController *)target { if((self=[super init]))_target=target;return self; }
- (void)tick:(CADisplayLink *)link { [_target bl_liveDisplayLinkTick:link]; }
@end

typedef struct {
    vector_float2 resolution; float contentsScale; vector_float2 touchPoint;
    float shapeMergeSmoothness,cornerRadius,cornerRoundnessExponent;
    vector_float4 materialTint;
    float glassThickness,refractiveIndex,dispersionStrength,fresnelDistanceRange,fresnelIntensity,fresnelEdgeSharpness;
    float glareDistanceRange,glareAngleConvergence,glareOppositeSideBias,glareIntensity,glareEdgeSharpness,glareDirectionOffset;
    int32_t rectangleCount; vector_float4 rectangles[16];
} CCPShaderUniforms;

@implementation CCPerspectiveGlassController {
    __weak UIView *_targetView; __weak UIView *_captureSourceView;
    NSInteger _style; CAMetalLayer *_metalLayer; CCPerspectiveBackdropView *_backdropView;
    id<MTLDevice> _device; id<MTLCommandQueue> _commandQueue; id<MTLRenderPipelineState> _pipelineState;
    id<MTLBuffer> _uniformsBuffer; CCPerspectiveZeroCopyBridge *_zeroCopyBridge; id<MTLTexture> _backgroundTexture, _blurredTexture;
    CADisplayLink *_displayLink; CCPerspectiveGlassDisplayLinkProxy *_displayLinkProxy;
    BOOL _invalidated,_renderScheduled,_hasRenderedFrame,_gpuInFlight;
    NSUInteger _refreshGeneration; CFTimeInterval _lastRenderTime,_revealNotBefore;
    CGRect _lastTargetBounds,_lastTargetFrameInHost; CGFloat _lastContentsScale; CGSize _lastBufferSize;
}
- (instancetype)initWithTargetView:(UIView *)view { return [self initWithTargetView:view style:0]; }
- (instancetype)initWithTargetView:(UIView *)view style:(NSInteger)style {
    if((self=[super init])){
        _targetView=view;_style=style;_magnification=2.0;_continuousRefreshEnabled=YES;_capturesFromWindow=YES;_targetFramesPerSecond=60;
        _device=MTLCreateSystemDefaultDevice(); if(!_device)return self;
        _commandQueue=[_device newCommandQueue]; _zeroCopyBridge=[[CCPerspectiveZeroCopyBridge alloc]initWithDevice:_device];
        _metalLayer=[CAMetalLayer layer];_metalLayer.device=_device;_metalLayer.pixelFormat=MTLPixelFormatBGRA8Unorm;
        _metalLayer.opacity=0;
        _metalLayer.framebufferOnly=YES;_metalLayer.opaque=NO;_metalLayer.presentsWithTransaction=NO;
        _backdropView=[[CCPerspectiveBackdropView alloc]initWithFrame:_targetView.bounds];_backdropView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[_targetView insertSubview:_backdropView atIndex:0];
        [_targetView.layer addSublayer:_metalLayer]; [self compileShaders]; [self updateLayout];
        _revealNotBefore=CACurrentMediaTime()+.05;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationDidBecome:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }return self;
}
- (void)setCaptureSourceView:(UIView *)source { _captureSourceView=source; [self scheduleRender]; }
- (void)setMagnification:(CGFloat)value { _magnification=MAX(1.0,value); [self scheduleRender]; }
- (void)compileShaders {
    NSString *path=[[NSBundle bundleForClass:self.class]pathForResource:@"LiquidGlass" ofType:@"metal"];
    NSString *source=path?[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]:nil;
    NSError *error=nil; id<MTLLibrary> library=source?[_device newLibraryWithSource:source options:nil error:&error]:nil;
    id<MTLFunction> vertex=[library newFunctionWithName:@"fullscreenQuad"],fragment=[library newFunctionWithName:@"liquidGlassEffect"];
    if(!vertex||!fragment)return;
    MTLRenderPipelineDescriptor *d=[MTLRenderPipelineDescriptor new];d.vertexFunction=vertex;d.fragmentFunction=fragment;d.colorAttachments[0].pixelFormat=_metalLayer.pixelFormat;
    d.colorAttachments[0].blendingEnabled=YES;d.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;d.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
    d.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorOne;d.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
    _pipelineState=[_device newRenderPipelineStateWithDescriptor:d error:&error]; _uniformsBuffer=[_device newBufferWithLength:sizeof(CCPShaderUniforms) options:MTLResourceStorageModeShared];
}
- (void)startLiveRefresh {
    if(_displayLink||_invalidated)return; _displayLinkProxy=[[CCPerspectiveGlassDisplayLinkProxy alloc]initWithTarget:self];
    _displayLink=[CADisplayLink displayLinkWithTarget:_displayLinkProxy selector:@selector(tick:)];
    NSInteger fps=_targetView.window.screen.maximumFramesPerSecond; if(fps<=0)fps=60; _targetFramesPerSecond=fps;
    _displayLink.preferredFramesPerSecond=fps;[_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];[self scheduleRender];
}
- (void)bl_liveDisplayLinkTick:(CADisplayLink *)link {
    (void)link;if(_invalidated||!_continuousRefreshEnabled||!_targetView.window||CGRectIsEmpty(_targetView.bounds))return;
    UIView *source=[self effectiveCaptureSource];if(!source)return;CGRect f=[_targetView convertRect:_targetView.bounds toView:source];
    if(!CGRectIntersectsRect(CGRectInset(source.bounds,-24,-24),f))return;[self scheduleRender];
}
- (UIView *)effectiveCaptureSource {
    if(_capturesFromWindow){UIWindow *overlay=_targetView.window;for(UIWindow *w in overlay.windowScene.windows.reverseObjectEnumerator)if(w!=overlay&&!w.hidden&&w.alpha>0)return w;}
    return _captureSourceView ?: _targetView.window;
}
- (void)scheduleRender {
    if(_invalidated||_renderScheduled||_gpuInFlight)return;_renderScheduled=YES;
    CFTimeInterval interval=1.0/MAX(1,_targetFramesPerSecond?:60),delay=MAX(0.0,interval-(CACurrentMediaTime()-_lastRenderTime));
    NSUInteger generation=_refreshGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(self->_invalidated||generation!=self->_refreshGeneration){self->_renderScheduled=NO;return;}
        CFTimeInterval remaining=interval-(CACurrentMediaTime()-self->_lastRenderTime);
        if(remaining>0){self->_renderScheduled=NO;[self scheduleRender];return;}
        [self refresh];
    });
}
- (void)updateLayout {
    UIView *v=_targetView;if(!v)return;CGFloat scale=v.window.screen.scale?:UIScreen.mainScreen.scale;
    _metalLayer.frame=v.bounds;_metalLayer.contentsScale=scale;_metalLayer.drawableSize=CGSizeMake(MAX(1,v.bounds.size.width*scale),MAX(1,v.bounds.size.height*scale));
    if(!CGSizeEqualToSize(_lastBufferSize,_metalLayer.drawableSize)){_refreshGeneration++;_hasRenderedFrame=NO;_metalLayer.opacity=0;_revealNotBefore=CACurrentMediaTime()+.05;}
    _lastTargetBounds=v.bounds;_lastContentsScale=scale;_lastBufferSize=_metalLayer.drawableSize;
}
- (void)refresh {
    _renderScheduled=NO;if(_invalidated||_gpuInFlight)return;[self updateLayout];UIView *source=[self effectiveCaptureSource];UIView *target=_targetView;if(!source||!target)return;
    CGSize px=_metalLayer.drawableSize;if(![_zeroCopyBridge setupBufferWithWidth:(size_t)px.width height:(size_t)px.height])return;
    CGRect inSource=[target convertRect:target.bounds toView:source];CGFloat scale=_lastContentsScale,mag=_magnification;
    BOOL targetWasHidden=target.hidden;target.hidden=YES;
    _backgroundTexture=[_zeroCopyBridge renderWithActions:^(CGContextRef ctx){
        CGContextSaveGState(ctx);CGContextScaleCTM(ctx,scale,scale);
        CGPoint c=CGPointMake(CGRectGetMidX(inSource),CGRectGetMidY(inSource));
        CGContextTranslateCTM(ctx,target.bounds.size.width/2.0,target.bounds.size.height/2.0);CGContextScaleCTM(ctx,mag,mag);CGContextTranslateCTM(ctx,-c.x,-c.y);
        UIGraphicsPushContext(ctx);BOOL ok=[source drawViewHierarchyInRect:source.bounds afterScreenUpdates:NO];UIGraphicsPopContext();
        if(!ok)[source.layer renderInContext:ctx];CGContextRestoreGState(ctx);
    }];
    target.hidden=targetWasHidden;
    if(!_backgroundTexture)return;[self blurBackgroundTextureIfNeeded];[self renderFrame];_lastRenderTime=CACurrentMediaTime();
}
- (void)blurBackgroundTextureIfNeeded {
    if(_style<=0||!_backgroundTexture)return;
    MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_backgroundTexture.pixelFormat width:_backgroundTexture.width height:_backgroundTexture.height mipmapped:NO];td.usage=MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite;
    if(!_blurredTexture||_blurredTexture.width!=td.width||_blurredTexture.height!=td.height)_blurredTexture=[_device newTextureWithDescriptor:td];
    id<MTLCommandBuffer> cb=[_commandQueue commandBuffer];MPSImageGaussianBlur *blur=[[MPSImageGaussianBlur alloc]initWithDevice:_device sigma:8.0];[blur encodeToCommandBuffer:cb sourceTexture:_backgroundTexture destinationTexture:_blurredTexture];[cb commit];[cb waitUntilCompleted];if(cb.status==MTLCommandBufferStatusCompleted)_backgroundTexture=_blurredTexture;
}
- (void)updateUniforms {
    CCPShaderUniforms *u=(CCPShaderUniforms *)_uniformsBuffer.contents;memset(u,0,sizeof(*u));CGSize p=_targetView.bounds.size;
    u->resolution=(vector_float2){(float)_metalLayer.drawableSize.width,(float)_metalLayer.drawableSize.height};u->contentsScale=_lastContentsScale;u->touchPoint=(vector_float2){p.width/2,p.height/2};
    u->shapeMergeSmoothness=12;u->cornerRadius=MIN(p.width,p.height)/2;u->cornerRoundnessExponent=2;
    u->materialTint=(vector_float4){.96,.98,1,.08};u->glassThickness=35;u->refractiveIndex=1.12;u->dispersionStrength=1;
    u->fresnelDistanceRange=45;u->fresnelIntensity=.7;u->fresnelEdgeSharpness=.15;u->glareDistanceRange=60;u->glareAngleConvergence=.5;u->glareOppositeSideBias=.75;u->glareIntensity=.55;u->glareEdgeSharpness=.12;u->glareDirectionOffset=0;
    u->rectangleCount=1;u->rectangles[0]=(vector_float4){0,0,p.width,p.height};
}
- (void)renderFrame {
    if(!_pipelineState||!_backgroundTexture||_gpuInFlight)return;id<CAMetalDrawable> drawable=[_metalLayer nextDrawable];if(!drawable)return;[self updateUniforms];
    MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];pass.colorAttachments[0].texture=drawable.texture;pass.colorAttachments[0].loadAction=MTLLoadActionClear;pass.colorAttachments[0].storeAction=MTLStoreActionStore;pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,0);
    id<MTLCommandBuffer> cb=[_commandQueue commandBuffer];id<MTLRenderCommandEncoder> e=[cb renderCommandEncoderWithDescriptor:pass];[e setRenderPipelineState:_pipelineState];[e setFragmentBuffer:_uniformsBuffer offset:0 atIndex:0];[e setFragmentTexture:_backgroundTexture atIndex:0];[e drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];[e endEncoding];[cb presentDrawable:drawable];
    _gpuInFlight=YES;NSUInteger generation=_refreshGeneration;__weak typeof(self) weakSelf=self;[cb addCompletedHandler:^(__unused id<MTLCommandBuffer> done){dispatch_async(dispatch_get_main_queue(),^{typeof(self) self=weakSelf;if(!self)return;self->_gpuInFlight=NO;if(!self->_invalidated&&generation==self->_refreshGeneration){self->_hasRenderedFrame=YES;if(CACurrentMediaTime()>=self->_revealNotBefore)self->_metalLayer.opacity=1;[self scheduleRender];}});}];[cb commit];
}
- (void)captureBackdrop { if(!_invalidated)[self scheduleRender]; }
- (void)applicationWillResign:(NSNotification *)note { (void)note;_displayLink.paused=YES;_refreshGeneration++;_renderScheduled=NO; }
- (void)applicationDidBecome:(NSNotification *)note { (void)note;if(!_invalidated){_displayLink.paused=NO;[self scheduleRender];} }
- (void)invalidate { if(_invalidated)return;_invalidated=YES;_refreshGeneration++;[[NSNotificationCenter defaultCenter]removeObserver:self];[_displayLink invalidate];_displayLink=nil;_displayLinkProxy=nil;[_zeroCopyBridge invalidate];_backgroundTexture=nil;_blurredTexture=nil;[_backdropView removeFromSuperview];_backdropView=nil;[_metalLayer removeFromSuperlayer];_metalLayer=nil; }
- (void)dealloc { [self invalidate]; }
@end
