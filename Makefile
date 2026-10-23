export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:16.0
export THEOS_PACKAGE_SCHEME = rootless
PACKAGE_FORMAT = deb

# Installs into /var/jb/Library/ControlCenter/Bundles; SpringBoard loads it on
# respring/restart. No maintainer scripts are shipped.
export INSTALL_TARGET_PROCESSES = SpringBoard

BUNDLE_NAME = CCPerspective

# Standard Theos bundle layout: Sources/ + Resources/ + Info.plist next to this
# Makefile. Theos only auto-detects the bundle Info.plist in that layout.
CCPerspective_FILES = Sources/CCPerspectiveModule.m Sources/CCPerspectiveViewController.m Sources/LiveLens.m Sources/ZeroCopyBridge.m Sources/GlassController.m
CCPerspective_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -IHeaders
CCPerspective_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics Metal MetalKit MetalPerformanceShaders CoreVideo IOSurface AudioToolbox
CCPerspective_PRIVATE_FRAMEWORKS = ControlCenterUIKit
CCPerspective_INSTALL_PATH = /Library/ControlCenter/Bundles
CCPerspective_RESOURCE_DIRS = Resources

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

# Fail loudly instead of shipping a bundle without its Info.plist.
after-package-check::
	@find "$(THEOS_STAGING_DIR)" -name Info.plist -path '*CCPerspective.bundle*' | grep -q . \
		|| { echo "error: staged bundle has no Info.plist"; exit 1; }
