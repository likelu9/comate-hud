#!/usr/bin/env bash
# 一次性生成自签名代码签名身份「Comate HUD Local Signing」并导入登录钥匙串。
#
# 为什么需要它（见 build.sh 签名段落）：ad-hoc 签名的指定要求是 `cdhash H"..."`，
# 每次重建都变；WebKit 的 WebCrypto 主密钥存在钥匙串、ACL 记的是创建者身份，
# 身份一变就要重新授权 → 用户每次升级都看到「ComateHUD 想要使用你储存在钥匙串中的…」。
# 换成证书签名后指定要求 = `identifier "com.wpscomate.hud" and certificate root = H"…"`，
# 跨构建恒定，授权可沿用。
#
# 私钥只留在本机登录钥匙串（不进仓库）；证书丢了就重跑本脚本再重建即可，
# 代价是已发用户会被再授权一次。
#
# 脚本同时会把 codesign 放行写入这把私钥的 partition 列表：`security import` 导进来的
# 私钥只带 `apple-tool:`，而 codesign 的 client partition 是 `apple:`，不补上则每次
# build.sh 签名都会弹「codesign 想要使用…」（每次 2 次，且点「允许」不记住）。
# 这一步需要登录钥匙串密码，所以放在本脚本（本来就是手动跑的一次性设置）里问一次。
set -euo pipefail

ID="Comate HUD Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# 让 codesign 免授权使用签名私钥（缺 `apple:` 就会每次构建弹授权框）。
# 密码由 security 交互式询问，不要用 -k 传（会留在 shell 历史与进程参数里）。
ensure_codesign_access() {
    echo "==> 放行 codesign 使用签名私钥（会提示输入登录钥匙串密码）"
    if security set-key-partition-list -S apple-tool:,apple:,codesign: -l "$ID" "$KEYCHAIN"; then
        echo "✅ codesign 已可免授权使用「$ID」，构建不会再弹钥匙串授权框"
    else
        echo "⚠ partition 列表未更新（未输密码 / 密码不对）：构建时仍会弹授权框"
        echo "  可重跑本脚本，或手动执行："
        echo "  security set-key-partition-list -S apple-tool:,apple:,codesign: -l \"$ID\" \"$KEYCHAIN\""
    fi
}

if security find-certificate -c "$ID" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "签名身份已存在：$ID"
    ensure_codesign_access
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 \
    -subj "/CN=$ID/O=Comate HUD/C=CN" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" 2>/dev/null

openssl pkcs12 -export -out "$TMP/id.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout pass:hudlocal -name "$ID" 2>/dev/null

security import "$TMP/id.p12" -k "$KEYCHAIN" -P hudlocal \
    -T /usr/bin/codesign -T /usr/bin/security
echo "已导入签名身份：$ID"
ensure_codesign_access
