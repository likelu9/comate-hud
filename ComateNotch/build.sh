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
