#!/bin/bash
# 纯逻辑测试：只编译并运行可脱离界面验证的逻辑（版本比较 / 面板高度公式 / 状态灯判定）。
# 不启动 UI、不写用户目录、不发网络请求。
#
# 为什么不用 XCTest：本仓库手写 build.sh、无 SPM 依赖，引入 XCTest 需要额外 target 与
# 测试宿主；这里只需要断言 + 退出码，用顶层代码（Tests/main.swift）最省事。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
OUT="$ROOT/build/tests"

SDK_PATH=$(xcrun --show-sdk-path)
mkdir -p "$OUT"

# 排除 UI 入口：ComateHUDApp 的 @main 与 Tests/main.swift 的顶层代码不能共存；
# AppDelegate 只被前者引用，一并排除即可。
SOURCES=()
while IFS= read -r f; do
    case "$(basename "$f")" in
        ComateHUDApp.swift|AppDelegate.swift) continue ;;
    esac
    SOURCES+=("$f")
done < <(ls "$SRC"/*.swift)

echo "==> 编译测试（源文件 $(( ${#SOURCES[@]} + 1 )) 个）"
swiftc -sdk "$SDK_PATH" -target arm64-apple-macos12.0 \
    -framework AppKit -framework SwiftUI -framework Combine -framework CoreFoundation \
    "${SOURCES[@]}" "$ROOT/Tests/main.swift" -o "$OUT/logic-tests"

echo "==> 运行断言"
"$OUT/logic-tests"

echo "✅ 逻辑测试通过: $OUT/logic-tests"
