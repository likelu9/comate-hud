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
#   4. 重新部署前端页面到 Comate
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

# 用 Node.js 更新 JSON（macOS 自带）
node -e "
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
  } else {
    console.log('✅ 已回填 v${VERSION} size -> ${SIZE_STR}（build ${BUILD_NUM}，未新增条目）');
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
}

// latest 始终取列表首项，避免重跑旧版本时把 latest 回退
data.latest = data.versions[0].version;

fs.writeFileSync('versions.json', JSON.stringify(data, null, 2) + '\n');
console.log('⚠ 请编辑 versions.json 填写本次更新的具体 changelog');
"
echo ""

# --- Step 4: 部署到 Comate ---
echo "==> Step 4: 部署前端页面"
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
echo "  3. GitHub Release tag 用 v${VERSION}（静默发版用 v${VERSION}-${BUILD_NUM}）——不要写成更高的营销版本号，否则会误触发全体红点"
echo "============================================"
