#!/bin/bash
# ============================================================
# Comate HUD 版本发布脚本
# 用法: ./release.sh <version> <build_num> [site_version]
# 示例: ./release.sh 1.4.1 9 1.4.15
#
# 流程:
#   1. 读取 versions.json，添加新版本条目
#   2. 运行 build.sh 构建新 DMG
#   3. 更新 versions.json 的 latest 字段
#   4. 发布 GitHub Release（客户端「有新版本」红点的唯一来源）
#   5. 重新部署前端页面到 Comate
#
# 「发版」一定要同时做两件事，少一件就有一半用户收不到：
#   versions.json → 官网下载页的版本号与安装包
#   GitHub Release → 客户端更新红点（UpdateChecker 读 releases.atom 最新一条 entry 的版本号）
# 只想发官网、跳过 GitHub Release：SKIP_GH_RELEASE=1 ./release.sh ...
#
# 版本号有两个独立空间，别混用：
#   <version>       客户端版本（Info.plist / DMG 名 / versions.json），跟 App 一起发
#   [site_version]  官网站内版本（平台递增计数器，取 code status 的 latest_version +1），省略时用 <version>
#
# 两条发版轨道（详见 AGENTS.md）：
#   升营销版本（1.4.2 -> 1.4.3）     客户端会亮红点提示更新
#   只升 build 号（1.4.2 10 -> 11）  静默发版，不触发更新检查；GitHub tag 请用 v1.4.2-11，
#                                   千万不要写成更高的营销版本号（会误触发全体红点）
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HUD_DIR="$ROOT_DIR/ComateHUD"
VERSIONS_FILE="$HUD_DIR/versions.json"
BUILD_SCRIPT="$ROOT_DIR/ComateNotch/build.sh"

# --- 参数检查 ---
VERSION="${1:-}"
BUILD_NUM="${2:-}"
SITE_VERSION="${3:-${VERSION}}"
if [[ -z "$VERSION" || -z "$BUILD_NUM" ]]; then
  echo "❌ 用法: $0 <version> <build_num> [site_version]"
  echo "   示例: $0 1.4.1 9 1.4.15"
  exit 1
fi

echo "==> Comate HUD v${VERSION} (build ${BUILD_NUM}) 发布流程"
echo "    官网站内版本: ${SITE_VERSION}"
echo ""

# --- Step 1: 构建新版本 ---
echo "==> Step 1: 构建 DMG"
cd "$ROOT_DIR/ComateNotch"
bash "$BUILD_SCRIPT" 2>&1 | grep -E "^(==>|⚠|OUTPUT)" || true
echo ""

# --- Step 2: 复制 DMG 到部署目录 ---
echo "==> Step 2: 复制 DMG"
DMG_SRC="$ROOT_DIR/ComateNotch/dist/ComateHUD-${VERSION}.dmg"
DMG_DST="$HUD_DIR/ComateHUD-${VERSION}.dmg"
if [[ -f "$DMG_SRC" ]]; then
  cp "$DMG_SRC" "$DMG_DST"
  echo "✅ DMG 已复制: $(ls -lh "$DMG_DST" | awk '{print $5}')"
else
  echo "⚠ 未找到 DMG: $DMG_SRC"
  echo "  DMG 下载路径将不可用，请手动复制"
fi
echo ""

# --- Step 2.5: 计算 DMG 实际体积（官网体积的唯一真值来源）---
echo "==> Step 2.5: 计算安装包体积"
SIZE_STR="-"
if [[ -f "$DMG_DST" ]]; then
  DMG_BYTES=$(stat -f%z "$DMG_DST" 2>/dev/null || stat -c%s "$DMG_DST" 2>/dev/null || echo 0)
  if [[ "$DMG_BYTES" =~ ^[0-9]+$ && "$DMG_BYTES" -gt 0 ]]; then
    SIZE_STR=$(awk -v b="$DMG_BYTES" 'BEGIN{
      if (b >= 1048576)   printf "%.1f MB", b/1048576;
      else if (b >= 1024) printf "%.0f KB", b/1024;
      else                printf "%d B", b;
    }')
    echo "✅ 安装包体积: $SIZE_STR ($DMG_BYTES bytes) -> versions.json"
  else
    echo "⚠ 无法读取 DMG 字节数，size 保持 '-'（官网将隐藏体积行，不写假数据）"
  fi
else
  echo "⚠ 未找到 DMG，size 保持 '-'（官网将隐藏体积行，不写假数据）"
fi
echo ""

# --- Step 3: 更新 versions.json ---
echo "==> Step 3: 更新版本清单"
cd "$HUD_DIR"

# 用 Node.js 更新 JSON（macOS 自带）。
# 末尾的 __MODE__=... 行回传本次发布模式，供 Step 4 决定 GitHub tag：
#   marketing → 新营销版本（tag v1.4.5）    build-bump → 同营销版本只升 build（tag v1.4.5-14）
STEP3_OUT="$(node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('versions.json', 'utf8'));

// 版本已存在时：原地更新（幂等重跑不新增条目）。
// 只升 build 号 = 静默发版：build 必须一起回填，否则 check-docs 会因
// Info.plist build 与 versions.json build 不一致而拦下 build.sh。
const idx = data.versions.findIndex(v => v.version === '${VERSION}');
if (idx >= 0) {
  const entry = data.versions[idx];
  const prevBuild = typeof entry.build === 'number' ? entry.build : 0;
  entry.size = '${SIZE_STR}';
  entry.download = 'ComateHUD-${VERSION}.dmg';
  if (${BUILD_NUM} > prevBuild) {
    entry.build = ${BUILD_NUM};
    entry.date = new Date().toISOString().split('T')[0];
    console.log('✅ 静默发版：v${VERSION} build ' + prevBuild + ' -> ${BUILD_NUM}（营销版本不变 → 不触发更新检查红点）');
    console.log('⚠ 记得往 v${VERSION} 那条的 changelog 追加本次改动，官网才看得到');
    console.log('__MODE__=build-bump');
  } else {
    console.log('✅ 已回填 v${VERSION} size -> ${SIZE_STR}（build ${BUILD_NUM}，未新增条目）');
    console.log('__MODE__=rerun');
  }
} else {
  // 新增新版本到最前面（size 取 Step 2.5 实测值，不再写死 '-'）
  data.versions.unshift({
    version: '${VERSION}',
    build: ${BUILD_NUM},
    date: new Date().toISOString().split('T')[0],
    platform: 'macOS',
    size: '${SIZE_STR}',
    download: 'ComateHUD-${VERSION}.dmg',
    minOS: '12.0',
    changelog: [
      { type: 'new', text: '待填写更新内容' }
    ]
  });
  console.log('✅ versions.json 已更新: 新增 v${VERSION}（size ${SIZE_STR}）');
  console.log('__MODE__=marketing');
}

// latest 始终取列表首项，避免重跑旧版本时把 latest 回退
data.latest = data.versions[0].version;

fs.writeFileSync('versions.json', JSON.stringify(data, null, 2) + '\n');
console.log('⚠ 请编辑 versions.json 填写本次更新的具体 changelog');
"
)"
printf '%s\n' "$STEP3_OUT" | grep -v '^__MODE__=' || true
MODE="$(printf '%s\n' "$STEP3_OUT" | sed -n 's/^__MODE__=//p' | tail -1)"
echo ""

# --- Step 3.5: 官网渲染自检（发布前必过）---
# versions.json 刚被 Step 3 改过，官网靠它渲染；这里用真实脚本跑一遍，拦住
# 「数据改完官网渲染不出来」（例如新条目漏填 changelog）这类要等下次发官网才暴露的问题。
echo "==> Step 3.5: 官网渲染自检"
if ! node "$HUD_DIR/scripts/check-site.js"; then
  echo ""
  echo "❌ 官网渲染自检未通过 —— 已中止发布。"
  echo "   versions.json 刚被 Step 3 改过，官网此刻渲染不出来；先修 index.html / versions.json 再重跑。"
  exit 1
fi
echo ""

# --- Step 4: 发布 GitHub Release（更新红点的唯一来源）---
# 没这一步，官网上写了新版本、用户端也不会亮红点（v1.4.4 就是这么漏掉的：
# 官网有 1.4.4，但 GitHub 上只有 v1.4.3，所以 1.4.4 用户当时什么提示都没有）。
# tag 规则：营销版本 bump 用 v1.4.5；同营销版本只升 build 用 v1.4.5-14
#（客户端只取 tag 里第一段 x.y.z，所以两种写法解析出来都是 1.4.5，不会误报）。
echo "==> Step 4: 发布 GitHub Release"
RELEASE_DMG="$HUD_DIR/ComateHUD-${VERSION}.dmg"
case "${MODE:-marketing}" in
  build-bump) TAG="v${VERSION}-${BUILD_NUM}"; RELEASE_TITLE="Comate HUD v${VERSION} (build ${BUILD_NUM})" ;;
  *)          TAG="v${VERSION}";           RELEASE_TITLE="Comate HUD v${VERSION}" ;;
esac
# 静默发版不动 GitHub 的 Latest 标记（否则下载页会把 build 包当最新对外版本）
if [[ "$TAG" == "v${VERSION}" ]]; then LATEST_ARG="--latest"; else LATEST_ARG=""; fi

echo "   模式: ${MODE:-marketing} | tag: $TAG"
if [[ "${SKIP_GH_RELEASE:-}" == "1" ]]; then
  echo "⏭  SKIP_GH_RELEASE=1，已跳过 GitHub Release"
  echo "   ⚠ 不补发的话，用户端收不到本次更新红点"
elif ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "❌ 无法发布 GitHub Release：gh 未安装或未登录（先跑 gh auth login）"
  echo "   网站未部署（本步在 Step 5 之前），修好后重跑本脚本即可。"
  exit 1
elif [[ ! -f "$RELEASE_DMG" ]]; then
  echo "❌ 缺少 Release 产物: $RELEASE_DMG"
  exit 1
else
  # 正文由 versions.json 的 changelog 生成，与官网同源（含同一套 type 标签映射）
  NOTES_FILE="$(mktemp -t hud-release-notes)"
  trap 'rm -f "$NOTES_FILE"' EXIT
  VERSION="$VERSION" NOTES_FILE="$NOTES_FILE" node -e '
const fs = require("fs");
const data = JSON.parse(fs.readFileSync("versions.json", "utf8"));
const v = data.versions.find(function (x) { return x.version === process.env.VERSION; });
var labels = { new: "✨ 新增", opt: "⚡ 优化", fix: "🔧 修复", arch: "🏗 架构" };
var lines = ((v && v.changelog) || [])
  .filter(function (c) { return c && c.text && c.text !== "待填写更新内容"; })
  .map(function (c) { return "- " + (labels[c.type] || c.type) + " " + c.text; });
if (!lines.length) { lines.push("- 本版本无对外可见变化（静默发版）"); }
fs.writeFileSync(process.env.NOTES_FILE, [
  lines.join("\n"),
  "",
  "**系统要求**：macOS " + ((v && v.minOS) || "12.0") + "+ · Apple Silicon & Intel",
  "**首次打开**：应用未使用 Apple 付费开发者证书签名，macOS 会拦截首次启动。放行方式：打开「系统设置」→「隐私与安全性」，在「安全性」区域点「仍要打开」并在二次弹窗确认、输入系统密码；或终端执行 `xattr -dr com.apple.quarantine /Applications/ComateHUD.app`",
  ""
].join("\n"));
'
  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "   Release $TAG 已存在 → 原地更新正文与产物"
    gh release edit "$TAG" --title "$RELEASE_TITLE" $LATEST_ARG --notes-file "$NOTES_FILE"
    gh release upload "$TAG" "$RELEASE_DMG" --clobber
  else
    echo "   新建 Release $TAG"
    gh release create "$TAG" --title "$RELEASE_TITLE" $LATEST_ARG \
      --target "$(git -C "$ROOT_DIR" rev-parse HEAD)" \
      --notes-file "$NOTES_FILE" "$RELEASE_DMG"
  fi
  echo "✅ GitHub Release: https://github.com/likelu9/comate-hud/releases/tag/$TAG"
  echo "   客户端改从 https://github.com/likelu9/comate-hud/releases.atom 读最新版本号"
fi
echo ""

# --- Step 5: 部署到 Comate ---
echo "==> Step 5: 部署前端页面"
bash /Users/likelu/.wpscomate/agent/skills/official/comate-cli/scripts/comate.sh code publish \
  --workspace "$HUD_DIR" \
  --version "${SITE_VERSION}" \
  --description "Comate HUD v${VERSION} - macOS AI 任务状态灯产品介绍与下载页" \
  --json 2>&1 | tail -10
echo ""

# --- 完成 ---
echo "============================================"
echo "✅ Comate HUD v${VERSION} 发布完成！"
echo ""
echo "产品介绍页: https://comate.wpsgo.com/s/HyDSehobOTHX/"
echo "下载 DMG:   ComateNotch/dist/ComateHUD-${VERSION}.dmg"
echo ""
echo "后续操作:"
echo "  1. 编辑 ComateHUD/versions.json 填写 changelog"
echo "  2. 重新运行: bash $0 ${VERSION} ${BUILD_NUM} ${SITE_VERSION}"
if [[ "${SKIP_GH_RELEASE:-}" == "1" ]]; then
  echo "  3. 本次跳过了 GitHub Release（用户端不会收到红点），补发："
  echo "     gh release create $TAG --title \"Comate HUD v${VERSION}\" $HUD_DIR/ComateHUD-${VERSION}.dmg"
fi
echo "============================================"
