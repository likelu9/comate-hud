#!/bin/bash
# ComateNotch 构建脚本：用 swiftc 直接编译为 .app bundle
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
BUILD="$ROOT/build"
APP="$BUILD/ComateNotch.app"

echo "==> 清理旧产物"
rm -rf "$APP"

echo "==> 编译 Swift 源码"
mkdir -p "$APP/Contents/MacOS"
swiftc \
    -O \
    -target arm64-apple-macos12.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework CoreFoundation \
    "$SRC/ComateNotchApp.swift" \
    "$SRC/AppDelegate.swift" \
    "$SRC/ComateStore.swift" \
    "$SRC/NotchPanel.swift" \
    "$SRC/NotchRootView.swift" \
    -o "$APP/Contents/MacOS/ComateNotch"

echo "==> 组装 bundle"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "==> 完成: $APP"
echo "OUTPUT=$APP"
