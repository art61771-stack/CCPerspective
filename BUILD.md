# Build

macOS + Xcode iOS SDK + Theos (rootless):

```sh
export THEOS=$HOME/theos
make clean package FINALPACKAGE=1
```

Output: `packages/com.binglan.ccperspective_1.0.1_iphoneos-arm64.deb`
(arm64 + arm64e, deployment target iOS 16.0, no maintainer scripts).
