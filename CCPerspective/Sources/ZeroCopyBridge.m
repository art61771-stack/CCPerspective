#import "CCPerspective.h"
#import <CoreVideo/CoreVideo.h>

@implementation CCPerspectiveZeroCopyBridge {
    id<MTLDevice> _device;
    CVMetalTextureCacheRef _textureCache;
    CVPixelBufferRef _pixelBuffer;
    CVMetalTextureRef _cvTexture;
    size_t _width, _height;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self=[super init])) { _device=device; CVMetalTextureCacheCreate(kCFAllocatorDefault,NULL,device,NULL,&_textureCache); }
    return self;
}
- (id<MTLTexture>)texture { return _cvTexture ? CVMetalTextureGetTexture(_cvTexture) : nil; }
- (BOOL)setupBufferWithWidth:(size_t)width height:(size_t)height {
    if (!width || !height) return NO;
    if (_pixelBuffer && width==_width && height==_height) return YES;
    if (_cvTexture) { CFRelease(_cvTexture); _cvTexture=NULL; }
    if (_pixelBuffer) { CVPixelBufferRelease(_pixelBuffer); _pixelBuffer=NULL; }
    NSDictionary *attrs=@{(id)kCVPixelBufferIOSurfacePropertiesKey:@{},(id)kCVPixelBufferMetalCompatibilityKey:@YES,(id)kCVPixelBufferCGImageCompatibilityKey:@YES};
    CVReturn status=CVPixelBufferCreate(kCFAllocatorDefault,width,height,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef)attrs,&_pixelBuffer);
    if(status!=kCVReturnSuccess)return NO;
    status=CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,_textureCache,_pixelBuffer,NULL,MTLPixelFormatBGRA8Unorm,width,height,0,&_cvTexture);
    if(status!=kCVReturnSuccess){CVPixelBufferRelease(_pixelBuffer);_pixelBuffer=NULL;return NO;}
    _width=width;_height=height; return YES;
}
- (id<MTLTexture>)renderWithActions:(void (^)(CGContextRef))actions {
    if(!_pixelBuffer||!actions)return nil;
    if(CVPixelBufferLockBaseAddress(_pixelBuffer,0)!=kCVReturnSuccess)return nil;
    void *base=CVPixelBufferGetBaseAddress(_pixelBuffer); size_t w=CVPixelBufferGetWidth(_pixelBuffer),h=CVPixelBufferGetHeight(_pixelBuffer),row=CVPixelBufferGetBytesPerRow(_pixelBuffer);
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx=CGBitmapContextCreate(base,w,h,8,row,cs,kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cs);
    if(ctx){CGContextClearRect(ctx,CGRectMake(0,0,w,h));actions(ctx);CGContextRelease(ctx);}
    CVPixelBufferUnlockBaseAddress(_pixelBuffer,0);
    CVMetalTextureCacheFlush(_textureCache,0);
    return self.texture;
}
- (void)invalidate { if(_cvTexture){CFRelease(_cvTexture);_cvTexture=NULL;} if(_pixelBuffer){CVPixelBufferRelease(_pixelBuffer);_pixelBuffer=NULL;} if(_textureCache){CFRelease(_textureCache);_textureCache=NULL;} }
- (void)dealloc { [self invalidate]; }
@end
