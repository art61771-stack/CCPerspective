export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:16.0
export THEOS_PACKAGE_SCHEME = rootless
PACKAGE_FORMAT = deb

# Installs into /var/jb/Library/ControlCenter/Bundles; SpringBoard loads it on
# respring/restart (no maintainer scripts in this package).
export INSTALL_TARGET_PROCESSES = SpringBoard

SUBPROJECTS += CCPerspective

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/aggregate.mk

# Theos' bundle.mk copies the bundle Info.plist by deriving its path from
# $(THEOS_PROJECT_DIR), which does not resolve when the bundle lives in a
# subproject directory here. Stage it explicitly so the packaged bundle is
# never shipped without a plist.
_INFO_PLIST := $(CURDIR)/CCPerspective/Info.plist
_STAGE_PLIST := $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/ControlCenter/Bundles/CCPerspective.bundle/Info.plist

internal-package-check::
	@test -s "$(_INFO_PLIST)" || { echo "missing source Info.plist: $(_INFO_PLIST)"; exit 1; }
	@mkdir -p "$(dir $(_STAGE_PLIST))"
	@cp "$(_INFO_PLIST)" "$(_STAGE_PLIST)"
	@echo "staged Info.plist -> $(_STAGE_PLIST)"
