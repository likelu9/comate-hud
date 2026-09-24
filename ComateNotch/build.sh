#!/bin/bash
# Comate HUD 构建脚本：双架构 universal + ad-hoc 签名
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
BUILD="$ROOT/build"
APP="$BUILD/ComateHUD.app"

# 从 Info.plist 读版本号
PLIST="$ROOT/Info.plist"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
echo "==> 版本: $VER ($BUILD_NUM)"

echo "==> 清理旧产物"
rm -rf "$BUILD"
mkdir -p "$BUILD/arm64" "$BUILD/x86_64"

SDK_PATH=$(xcrun --show-sdk-path)
COMMON_FLAGS=(-O -sdk "$SDK_PATH" -framework AppKit -framework SwiftUI -framework Combine -framework CoreFoundation)

SOURCES=(
    "$SRC/ComateHUDApp.swift"
    "$SRC/AppDelegate.swift"
    "$SRC/ComateStore.swift"
    "$SRC/UsageAPI.swift"
    "$SRC/SessionJournal.swift"
    "$SRC/NotchPanel.swift"
    "$SRC/NotchRootView.swift"
    "$SRC/HUDShared.swift"
    "$SRC/FloatingPanel.swift"
    "$SRC/ActivityReporter.swift"
    "$SRC/UserIdentity.swift"
)

# 确定是否能编译双架构
CAN_UNIVERSAL=true
echo "==> 编译 arm64"
if ! swiftc "${COMMON_FLAGS[@]}" -target arm64-apple-macos12.0 "${SOURCES[@]}" -o "$BUILD/arm64/ComateHUD"; then
    echo "⚠ arm64 编译失败"
    exit 1
fi

echo "==> 编译 x86_64"
if ! swiftc "${COMMON_FLAGS[@]}" -target x86_64-apple-macos12.0 "${SOURCES[@]}" -o "$BUILD/x86_64/ComateHUD"; then
    echo "⚠ x86_64 编译失败，仅用 arm64"
    CAN_UNIVERSAL=false
fi

echo "==> 组装 bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/"* "$APP/Contents/Resources/" 2>/dev/null || true

if $CAN_UNIVERSAL; then
    echo "==> lipo 合并 universal binary"
    lipo -create "$BUILD/arm64/ComateHUD" "$BUILD/x86_64/ComateHUD" -output "$APP/Contents/MacOS/ComateHUD"
else
    cp "$BUILD/arm64/ComateHUD" "$APP/Contents/MacOS/ComateHUD"
fi

echo "==> ad-hoc 签名"
codesign --force --sign - "$APP" 2>/dev/null || echo "⚠ 签名跳过"

# 验证
echo "==> 验证"
file "$APP/Contents/MacOS/ComateHUD"
codesign -dvvv "$APP" 2>/dev/null | head -5 || true

# 清理中间产物
rm -rf "$BUILD/arm64" "$BUILD/x86_64"

echo "==> 构建完成: $APP"
echo "OUTPUT=$APP"

# 打包 DMG
echo "==> 打包 DMG"
DIST="$ROOT/dist"
STAGING="$DIST/staging"
DMG="$DIST/ComateHUD-$VER.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/ComateHUD.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/安装说明.txt" <<'TXT'
Comate HUD —— 安装说明
============================

【安装】
把左侧的 Comate HUD.app 拖到右侧的 Applications 文件夹即可。

【首次打开】
本应用未使用 Apple 付费开发者证书签名，macOS 会拦截首次启动。
任选一种方式放行：

  方式一：右键点击 Comate HUD.app → 选择「打开」→ 在弹窗中再点「打开」

  方式二：打开「终端」，执行下面这行命令：
      xattr -dr com.apple.quarantine /Applications/ComateHUD.app
      然后双击启动

【首次启动会弹权限提示】
  · 读取 Comate 用量数据需要访问钥匙串，请选「始终允许」；
    若选「拒绝」，额度区会显示「—」，任务列表不受影响。

【使用】
  · 刘海 HUD 模式：常驻屏幕顶部刘海区，鼠标移上去展开任务面板
  · 任意悬浮模式：圆形悬浮球可拖到桌面任意位置，移上去展开面板
  · 右键菜单：切换显示模式 / 显示主窗口 / 最近记录条数 / 关于 / 退出

【系统要求】
macOS 12.0 或更高版本，支持 Apple 芯片与 Intel 芯片。
TXT
hdiutil create -volname "Comate HUD" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGING"
if hdiutil verify "$DMG" >/dev/null 2>&1; then
    echo "✅ DMG 校验通过: $(ls -lh "$DMG" | awk '{print $5}')"
else
    echo "⚠ DMG 校验失败"
fi
echo "OUTPUT=$DMG"
