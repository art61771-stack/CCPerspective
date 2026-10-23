ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CCPerspective

CCPerspective_FILES = Sources/CCPerspectiveModule.m Sources/CCPerspectiveViewController.m Sources/LiveLens.m Sources/ZeroCopyBridge.m Sources/GlassController.m
CCPerspective_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -IHeaders
CCPerspective_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics Metal MetalKit MetalPerformanceShaders CoreVideo IOSurface AudioToolbox
CCPerspective_PRIVATE_FRAMEWORKS = ControlCenterUIKit
CCPerspective_INSTALL_PATH = /Library/ControlCenter/Bundles
# Be explicit: Theos otherwise only auto-detects Info.plist in some layouts and
# silently ships a bundle without one.
CCPerspective_BUNDLE_INFO_PLIST = Info.plist
CCPerspective_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
