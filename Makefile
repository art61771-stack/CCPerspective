export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:16.0
export THEOS_PACKAGE_SCHEME = rootless
PACKAGE_FORMAT = deb

# Installs into /var/jb/Library/ControlCenter/Bundles; SpringBoard reloads it
# on respring/restart (no maintainer scripts in this package).
export INSTALL_TARGET_PROCESSES = SpringBoard

SUBPROJECTS += CCPerspective

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/aggregate.mk
