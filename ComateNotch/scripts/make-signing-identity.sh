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
set -euo pipefail

ID="Comate HUD Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$ID" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "签名身份已存在：$ID"
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
