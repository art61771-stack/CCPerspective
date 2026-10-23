# CCPerspective 放大镜 — 独立 deb 源码

从 [CCPerspective-Reconstructed](https://github.com/art61771-stack/CCPerspective-Reconstructed)（授权逆向重建源码）单独打包成 deb，与 CCDynamic 完全无关。

## 与原来的（origin 1.0.1）差异

| 项 | origin deb | 本仓库 |
| --- | --- | --- |
| Package | com.binglan.ccperspective | 同 |
| 安装路径 | `/var/jb/Library/ControlCenter/Bundles/CCPerspective.bundle` | 同 |
| Info.plist / NSPrincipalClass | CCPerspective / CCPerspectiveModule | 同 |
| 版本 | 1.0.1 | 1.0.1 |
| 实现 | 原生 Mach-O | 重建 ObjC + `LiquidGlass.metal` 文本 shader |
| 模块图标 | 原始资源 | 重建的资源（`icon@3x.png`，仅 716 B 简化图） |

## 构建（macOS + Theos，rootless）

```sh
export THEOS=$HOME/theos
make clean package FINALPACKAGE=1
# 产物: packages/com.binglan.ccperspective_1.0.1_iphoneos-arm64.deb
```

CI：`.github/workflows/build.yml`，推送到 main 后在 Actions 下载 `CCPerspective-deb`。

## 安装

```sh
sileo/dpkg -i com.binglan.ccperspective_1.0.1_iphoneos-arm64.deb
respring 或重启 SpringBoard
```

包内无安装/卸载脚本；arm64 + arm64e；依赖 firmware >= 16.0。

## 注意

- shader 与布局为按可观察行为重建，不是原始二进制逐字节还原，渲染细节可能和原版不完全一致。
- 镜片帧来自 UIKit 视图树重绘，跨进程/受保护内容不安全覆盖；真机需自行验证稳定性与功耗。
- 授权说明见 `AUTHOR` / `LICENSE_NOTICE` / `CREDITS`。
