#!/bin/bash
# ComateNotch 构建脚本：双架构 universal + ad-hoc 签名
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
BUILD="$ROOT/build"
APP="$BUILD/ComateNotch.app"

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
    "$SRC/ComateNotchApp.swift"
    "$SRC/AppDelegate.swift"
    "$SRC/ComateStore.swift"
    "$SRC/UsageAPI.swift"
    "$SRC/SessionJournal.swift"
    "$SRC/NotchPanel.swift"
    "$SRC/NotchRootView.swift"
)

# 确定是否能编译 x86_64
CAN_X86=true
echo "==> 编译 arm64"
swiftc "${COMMON_FLAGS[@]}" -target arm64-apple-macos12.0 "${SOURCES[@]}" -o "$BUILD/arm64/ComateNotch" 2>/dev/null || {
    echo "⚠ arm64 编译失败，回退到仅当前架构"
    CAN_X86=false
}

if $CAN_X86; then
    echo "==> 编译 x86_64"
    swiftc "${COMMON_FLAGS[@]}" -target x86_64-apple-macos12.0 "${SOURCES[@]}" -o "$BUILD/x86_64/ComateNotch" 2>/dev/null || {
        echo "⚠ x86_64 编译失败，仅用 arm64"
        CAN_X86=false
    }
fi

echo "==> 组装 bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/"* "$APP/Contents/Resources/" 2>/dev/null || true

if $CAN_X86; then
    echo "==> lipo 合并 universal binary"
    lipo -create "$BUILD/arm64/ComateNotch" "$BUILD/x86_64/ComateNotch" -output "$APP/Contents/MacOS/ComateNotch"
else
    cp "$BUILD/arm64/ComateNotch" "$APP/Contents/MacOS/ComateNotch"
fi

echo "==> ad-hoc 签名"
codesign --force --sign - "$APP" 2>/dev/null || echo "⚠ 签名跳过"

# 验证
echo "==> 验证"
file "$APP/Contents/MacOS/ComateNotch"
codesign -dvvv "$APP" 2>/dev/null | head -5 || true

# 清理中间产物
rm -rf "$BUILD/arm64" "$BUILD/x86_64"

echo "==> 构建完成: $APP"
echo "OUTPUT=$APP"
