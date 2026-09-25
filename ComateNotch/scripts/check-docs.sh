#!/bin/bash
# 文档 / 版本号一致性校验：防止「改了代码忘了改文档」这类漂移。
#
# 四项检查全部可机器判定、无主观判断，因此零误报：
#   1. Info.plist（版本号唯一真源）与官网 versions.json 对外声明一致
#   2. ComateNotch/TODO.md 顶部声明的版本号 / build 号与 Info.plist 一致
#   3. Sources/*.swift 全部登记进 build.sh 的 SOURCES（漏登记 = 文件不参与编译）
#   4. versions.json 声明的 DMG 确实存在
#
# build.sh 每次构建都会跑它。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PY="$(command -v python3 || true)"
if [ -z "$PY" ]; then
    echo "⚠ 未找到 python3，跳过文档校验"
    exit 0
fi

echo "==> 校验文档 / 版本号一致性"
"$PY" - "$ROOT" <<'PYEOF'
import json
import os
import plistlib
import re
import sys

root = sys.argv[1]
notch = os.path.join(root, "ComateNotch")
hud = os.path.join(root, "ComateHUD")
errors = []


def ok(msg):
    print("  ✓ " + msg)


def note(msg):
    print("  · " + msg)


# 1. Info.plist ↔ versions.json
with open(os.path.join(notch, "Info.plist"), "rb") as f:
    plist = plistlib.load(f)
app_ver = plist["CFBundleShortVersionString"]
app_build = int(plist["CFBundleVersion"])

with open(os.path.join(hud, "versions.json"), encoding="utf-8") as f:
    versions = json.load(f)
latest = versions.get("latest")
first = versions["versions"][0]

if latest == app_ver and first.get("version") == app_ver and int(first.get("build", -1)) == app_build:
    ok("版本号同源：Info.plist %s (build %s) == versions.json latest" % (app_ver, app_build))
else:
    errors.append(
        "版本号不一致：Info.plist %s (build %s) vs versions.json latest=%s / versions[0]=%s (build %s)"
        % (app_ver, app_build, latest, first.get("version"), first.get("build"))
    )

# 2. TODO.md 顶部版本声明
with open(os.path.join(notch, "TODO.md"), encoding="utf-8") as f:
    todo = f.read()
m = re.search(r"\*\*版本\*\*:\s*v?([0-9][0-9.]*)(?:\s*\(build\s*([0-9]+)\))?", todo)
if not m:
    errors.append("TODO.md 顶部缺少「**版本**: vX.Y.Z (build N)」声明")
elif m.group(1).rstrip(".") != app_ver:
    errors.append("TODO.md 声明版本 %s 与 Info.plist %s 不一致" % (m.group(1), app_ver))
elif m.group(2) and int(m.group(2)) != app_build:
    errors.append("TODO.md 声明的 build %s 与 Info.plist build %s 不一致" % (m.group(2), app_build))
else:
    ok("TODO.md 版本声明 == %s (build %s)" % (app_ver, app_build))

# 3. build.sh SOURCES 完整性
with open(os.path.join(notch, "build.sh"), encoding="utf-8") as f:
    build = f.read()
listed = set(re.findall(r'"\$SRC/([A-Za-z0-9_]+\.swift)"', build))
actual = {f for f in os.listdir(os.path.join(notch, "Sources")) if f.endswith(".swift")}
missing = sorted(actual - listed)
extra = sorted(listed - actual)
if missing:
    errors.append("未登记进 build.sh SOURCES（不会被编译）：" + ", ".join(missing))
if extra:
    errors.append("build.sh SOURCES 里已不存在的文件：" + ", ".join(extra))
if not missing and not extra:
    ok("SOURCES 完整：%d 个源文件全部登记" % len(actual))

# 4. 官网声明的下载包存在
#    例外：正在构建的版本（versions[0] == Info.plist 版本）的 DMG 由本次构建产出，
#    而本脚本在 build.sh 开头就跑（DMG 还没生成），此时只提示不报错。
#    其余情况（版本号已错开、DMG 却不在）说明官网会挂上不存在的下载链接，必须报错。
dmg = first.get("download", "")
if dmg:
    candidates = [os.path.join(hud, dmg), os.path.join(notch, "dist", dmg)]
    found = [p for p in candidates if os.path.exists(p)]
    if found:
        ok("官网下载包存在：%s" % os.path.relpath(found[0], root))
    elif first.get("version") == app_ver:
        note("官网下载包 %s 待本次构建产出（版本与 Info.plist 一致）" % dmg)
    else:
        errors.append("versions.json 声明的 %s 在 ComateHUD/ 与 ComateNotch/dist/ 都找不到" % dmg)

if errors:
    print("\n❌ 文档 / 版本校验未通过：")
    for e in errors:
        print("  · " + e)
    sys.exit(1)

print("\n✅ 文档 / 版本校验通过")
PYEOF
