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

# 文档 / 版本号一致性：版本号同源、TODO.md 声明、SOURCES 完整、DMG 存在
bash "$ROOT/scripts/check-docs.sh"

echo "==> 清理旧产物"
rm -rf "$BUILD"
mkdir -p "$BUILD/arm64" "$BUILD/x86_64"

SDK_PATH=$(xcrun --show-sdk-path)
COMMON_FLAGS=(-O -sdk "$SDK_PATH" -framework AppKit -framework SwiftUI -framework Combine -framework CoreFoundation -framework WebKit)

SOURCES=(
    "$SRC/ComateHUDApp.swift"
    "$SRC/AppDelegate.swift"
    "$SRC/ComateStore.swift"
    "$SRC/AuthSession.swift"
    "$SRC/WebCryptoKeyReset.swift"
    "$SRC/LoginWindow.swift"
    "$SRC/TaskModel.swift"
    "$SRC/UsageAPI.swift"
    "$SRC/SessionJournal.swift"
    "$SRC/NotchPanel.swift"
    "$SRC/NotchRootView.swift"
    "$SRC/NotchLayout.swift"
    "$SRC/HUDShared.swift"
    "$SRC/LogoMotion.swift"
    "$SRC/FloatingPanel.swift"
    "$SRC/ActivityReporter.swift"
    "$SRC/UserIdentity.swift"
    "$SRC/UpdateChecker.swift"
    "$SRC/LaunchAtLogin.swift"
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

# 签名：优先用稳定的本地签名身份。
# 背景：ad-hoc 签名的指定要求是 `cdhash H"..."`，每次重建都会变；
# 而 WebKit 的 WebCrypto 主密钥存在钥匙串里、ACL 记录的是创建者身份 ——
# 身份一变，读旧条目就要授权，用户每次升级/重建都会看到「ComateHUD 想要使用
# 你储存在钥匙串中的…」弹窗（且 ad-hoc 下「始终允许」记不住）。
# 用自签名证书后指定要求是 `identifier "com.wpscomate.hud" and certificate root = H"…"`，
# 跨构建恒定，授权能真正沿用。证书由 scripts/make-signing-identity.sh 一次性生成。
SIGN_ID="Comate HUD Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if security find-certificate -c "$SIGN_ID" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "==> 稳定身份签名（$SIGN_ID）"
    if codesign --force --deep --keychain "$KEYCHAIN" -s "$SIGN_ID" "$APP" 2>/dev/null; then
        echo "    指定要求: $(codesign -d -r- "$APP" 2>/dev/null | tail -1)"
    else
        echo "    ⚠ 稳定身份签名失败，回退 ad-hoc（身份将随构建变化）"
        codesign --force --sign - "$APP" 2>/dev/null || echo "⚠ 签名跳过"
    fi
else
    echo "==> ad-hoc 签名（未找到稳定身份，见 AGENTS.md「签名身份」）"
    codesign --force --sign - "$APP" 2>/dev/null || echo "⚠ 签名跳过"
fi

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
本应用未使用 Apple 付费开发者证书签名，macOS 会拦截首次启动
（提示「未打开“ComateHUD”」，Apple 无法验证其安全性）。
双击后按下面任一种方式放行：

  方式一（推荐，图形界面）：
      1. 双击 Comate HUD.app，出现「未打开“ComateHUD”」提示后关闭该弹窗
      2. 打开「系统设置」→「隐私与安全性」
      3. 下滑到「安全性」区域，找到「已阻止“ComateHUD”以保护 Mac」
      4. 点「仍要打开」，在二次弹窗「打开“ComateHUD”？」中再点「仍要打开」
      5. 输入系统密码，即可正常使用

  方式二（终端命令）：
      打开「终端」，执行下面这行命令：
      xattr -dr com.apple.quarantine /Applications/ComateHUD.app
      然后双击启动

【首次启动会引导登录】
  · 首次启动会弹出登录窗口，用 WPS 账号登录一次即可 ——
    未读消息、云端任务与额度用量需要登录后才能读取（任务状态灯始终可用）。
  · 凭证只保存在本机 HUD 自己的数据里（HUD 不读取你的文档内容）；
    登录失效时面板会提示，点一下即可重新登录，通常无需再扫码。

【使用】
  · 刘海 HUD 模式：常驻屏幕顶部刘海区，鼠标移上去展开任务面板
  · 任意悬浮模式：圆形悬浮球可拖到桌面任意位置，移上去展开面板
  · 右键菜单：WPS 账号（登录 / 退出登录）/ 切换显示模式 / 显示主窗口 / 最近记录条数 /
    检查更新 / 关于 / 退出

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
