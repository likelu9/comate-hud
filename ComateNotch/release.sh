#!/bin/bash
# ============================================================
# Comate HUD 版本发布脚本
# 用法: ./release.sh <version> <build_num>
# 示例: ./release.sh 1.3.0 4
#
# 流程:
#   1. 读取 versions.json，添加新版本条目
#   2. 运行 build.sh 构建新 DMG
#   3. 更新 versions.json 的 latest 字段
#   4. 重新部署前端页面到 Comate
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
if [[ -z "$VERSION" || -z "$BUILD_NUM" ]]; then
  echo "❌ 用法: $0 <version> <build_num>"
  echo "   示例: $0 1.3.0 4"
  exit 1
fi

echo "==> Comate HUD v${VERSION} (build ${BUILD_NUM}) 发布流程"
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

# --- Step 3: 更新 versions.json ---
echo "==> Step 3: 更新版本清单"
cd "$HUD_DIR"

# 用 Node.js 更新 JSON（macOS 自带）
node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('versions.json', 'utf8'));

// 检查版本是否已存在
if (data.versions.some(v => v.version === '${VERSION}')) {
  console.log('⚠ 版本 ${VERSION} 已存在于 versions.json，跳过添加');
  process.exit(0);
}

// 添加新版本到最前面
data.versions.unshift({
  version: '${VERSION}',
  build: ${BUILD_NUM},
  date: new Date().toISOString().split('T')[0],
  download: 'ComateHUD-${VERSION}.dmg',
  size: '-',
  minOS: '12.0',
  changelog: [
    { type: 'new', text: '待填写更新内容' }
  ]
});

data.latest = '${VERSION}';

fs.writeFileSync('versions.json', JSON.stringify(data, null, 2) + '\n');
console.log('✅ versions.json 已更新: latest -> v${VERSION}');
console.log('⚠ 请编辑 versions.json 填写本次更新的具体 changelog');
"
echo ""

# --- Step 4: 部署到 Comate ---
echo "==> Step 4: 部署前端页面"
bash /Users/likelu/.wpscomate/agent/skills/official/comate-cli/scripts/comate.sh code publish \
  --workspace "$HUD_DIR" \
  --version "${VERSION}" \
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
echo "  2. 重新运行: bash $0 ${VERSION} ${BUILD_NUM}"
echo "============================================"
