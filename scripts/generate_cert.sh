#!/bin/bash

# PrivacyIDEA Docker 証明書・暗号化キー生成スクリプト
# 更新日: 2025年6月23日
# 
# 公式entrypoint.py準拠の暗号化キー生成に対応
# 参考: https://github.com/gpappsoft/privacyidea-docker/blob/main/entrypoint.py
#
# 使い方:
#   bash generate_cert.sh
#   SANに含めるホスト名やIPアドレスはスクリプト先頭の変数で定義してください。
#   CA証明書（CN="帝釈天CA"）とWebサーバ証明書（CN="毘沙門天Web"）が config/nginx/cert に生成されます。
#   PrivacyIDEA用の暗号化キーファイル（enckey）、PI_PEPPER、PI_SECRETも自動生成されます。
#
# 生成されるファイル:
#   - nginx/certs/ca.crt - CA証明書（マスターファイル）
#   - nginx/certs/server.crt - Webサーバー証明書
#   - nginx/certs/server.key - Webサーバー秘密鍵
#   - freeradius/certs/radius.crt - RADIUSサーバー証明書
#   - freeradius/certs/radius.key - RADIUSサーバー秘密鍵
#   - freeradius/certs/ca.crt - CA証明書（nginx/certs/ca.crtへのハードリンク）
#   - privacyidea/certs/enckey - PrivacyIDEA暗号化キーファイル（96バイト、公式準拠）
#   - privacyidea/certs/private.pem - 監査ログ署名用RSA秘密鍵（4096bit強化版）
#   - privacyidea/certs/public.pem - 監査ログ署名用RSA公開鍵（4096bit強化版）
#   - .env - 環境変数設定（PI_SECRET、PI_PEPPER自動更新）
#
# 証明書仕様:
#   - 日本語CNをそのまま使用（Unicode対応）
#   - 適切なSAN（Subject Alternative Name）設定
#   - セキュリティ要件準拠の拡張設定
#   - 暗号化方式: ECDSA P-384 (384bit楕円曲線暗号)
#   - 署名アルゴリズム: ECDSA with SHA-384
#   - 監査ログ署名: RSA（PrivacyIDEA互換性のため）
#   - CA証明書有効期限: 10年間
#   - サーバー証明書有効期限: 10年間
#
# PaloAlto Networks RADIUS クライアント設定用:
#   PaloAltoに読み込ませるCAファイル: nginx/certs/ca.crt (マスターファイル)
#   または同一内容のハードリンク: freeradius/certs/ca.crt
#   ※FreeRADIUSのca.crtはnginx/certs/ca.crtへのハードリンクです

C="JP"                      # 国コード
O="PrivacyIDEA Corp."       # 組織名 (会社名)
CA_CN="帝釈天CA"            # CA証明書の Common Name

# --- Web サーバー用の設定
WEB_SERVER_CN="毘沙門天Web"        # Webサーバ証明書の Common Name
WEB_SERVER_DN="/C=${C}/O=${O}/CN=${WEB_SERVER_CN}"
WEB_CERT_DIR="nginx/certs"

# SANに含めるドメイン名やIPアドレス（カンマ区切りで指定）
# localhost, 127.0.0.1, ホスト名、外部IPを含める
WEB_SAN_ENTRIES="localhost,privacyidea.my.home,privacyidea,192.168.0.79"

# --- RADIUSサーバー用の設定
RADIUS_CN="広目天RAD"
RADIUS_DN="/C=${C}/O=${O}/CN=${RADIUS_CN}"
RADIUS_CERT_DIR="freeradius/certs"

# --- CA設定
CA_DN="/C=${C}/O=${O}/CN=${CA_CN}"

# === Webサーバー用証明書の生成 ===
mkdir -p $WEB_CERT_DIR

# 1. CA秘密鍵と自己署名CA証明書を生成
openssl ecparam -name secp384r1 -genkey -noout -out $WEB_CERT_DIR/ca.key

# CA証明書用の設定ファイル
CA_EXTFILE=$(mktemp)
cat > $CA_EXTFILE << EOF
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
EOF

openssl req -new -x509 -days 3650 -sha384 -key $WEB_CERT_DIR/ca.key -out $WEB_CERT_DIR/ca.crt -subj "${CA_DN}" -extensions v3_ca -config <(
cat << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[req_distinguished_name]

[v3_ca]
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
EOF
)

rm $CA_EXTFILE

# 2. Webサーバ秘密鍵とCSRを生成
openssl ecparam -name secp384r1 -genkey -noout -out $WEB_CERT_DIR/server.key
openssl req -new -sha384 -key $WEB_CERT_DIR/server.key -out $WEB_CERT_DIR/server.csr -subj "${WEB_SERVER_DN}"

# 3. SAN用の文字列を生成
WEB_SAN=""
IFS=',' read -ra ADDR <<< "$WEB_SAN_ENTRIES"
for h in "${ADDR[@]}"; do
    if [[ $h =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        WEB_SAN="${WEB_SAN}IP:${h},"
    else
        WEB_SAN="${WEB_SAN}DNS:${h},"
    fi
done
WEB_SAN=${WEB_SAN%,}

# 4. SAN拡張用設定ファイルを一時作成
EXTFILE=$(mktemp)
cat > $EXTFILE << EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = ${WEB_SAN}
authorityKeyIdentifier = keyid,issuer:always
subjectKeyIdentifier = hash
EOF

# 5. Webサーバ証明書をCAで署名
openssl x509 -req -days 3650 -sha384 -in $WEB_CERT_DIR/server.csr -CA $WEB_CERT_DIR/ca.crt -CAkey $WEB_CERT_DIR/ca.key -CAcreateserial -out $WEB_CERT_DIR/server.crt -extfile $EXTFILE

# === RADIUSサーバー用証明書の生成 ===
mkdir -p $RADIUS_CERT_DIR

# RADIUSサーバー秘密鍵とCSRを生成
openssl ecparam -name secp384r1 -genkey -noout -out $RADIUS_CERT_DIR/radius.key
openssl req -new -sha384 -key $RADIUS_CERT_DIR/radius.key -out $RADIUS_CERT_DIR/radius.csr -subj "${RADIUS_DN}"

# RADIUSサーバー証明書をCAで署名（SAN拡張も付与）
openssl x509 -req -days 3650 -sha384 -in $RADIUS_CERT_DIR/radius.csr -CA $WEB_CERT_DIR/ca.crt -CAkey $WEB_CERT_DIR/ca.key -CAcreateserial -out $RADIUS_CERT_DIR/radius.crt -extfile $EXTFILE

# 一時ファイルとCSRを削除
rm $WEB_CERT_DIR/server.csr $RADIUS_CERT_DIR/radius.csr $EXTFILE $WEB_CERT_DIR/ca.srl

# RADIUSディレクトリにCA証明書のハードリンクを作成
# ハードリンクの利点:
# - ディスク容量の節約（同一inodeを共有）
# - CA証明書の完全な一意性保証（物理的に同一ファイル）
# - パス依存の問題なし（シンボリックリンクの相対パス問題を回避）
# - 管理の簡素化（どちらのパスからでも同一ファイルにアクセス）
if [ -f "$RADIUS_CERT_DIR/ca.crt" ]; then
    rm -f "$RADIUS_CERT_DIR/ca.crt"
fi
ln "$WEB_CERT_DIR/ca.crt" "$RADIUS_CERT_DIR/ca.crt"

# FreeRADIUS用のファイル権限を設定
chmod 644 $RADIUS_CERT_DIR/radius.crt
chmod 600 $RADIUS_CERT_DIR/radius.key

# FreeRADIUSコンテナがrootで実行されるため、root:rootで設定
# セキュリティ上、秘密鍵は所有者のみ読み取り可能にする
chown root:root $RADIUS_CERT_DIR/radius.key 2>/dev/null || true

# === PrivacyIDEA監査ログ用証明書の生成（強化版：RSA 4096bit） ===
# 監査ログは改ざん防止とセキュリティ監査において極めて重要なため、
# RSA 4096bit の最高レベルのセキュリティを確保します。
# 
# 公式実装では RSA 2048bit ですが、ここでは 4096bit に強化
# 参考: https://github.com/gpappsoft/privacyidea-docker/blob/main/entrypoint.py
# （ECDSA は PrivacyIDEA の互換性問題のため RSA を使用）
AUDIT_CERT_DIR="privacyidea/certs"
mkdir -p $AUDIT_CERT_DIR

# 環境変数で指定されたパスを使用（公式実装準拠）
PRIV_KEY_PATH=${PI_AUDIT_KEY_PRIVATE:-$AUDIT_CERT_DIR/private.pem}
PUB_KEY_PATH=${PI_AUDIT_KEY_PUBLIC:-$AUDIT_CERT_DIR/public.pem}

# 監査ログ用のRSA秘密鍵を生成（4096bit、公式の2048bitから強化）
if [ ! -f "$PRIV_KEY_PATH" ]; then
    mkdir -p "$(dirname "$PRIV_KEY_PATH")"
    openssl genrsa -out "$PRIV_KEY_PATH" 4096
    chmod 600 "$PRIV_KEY_PATH"
    echo "監査ログ用RSA秘密鍵を生成しました: $PRIV_KEY_PATH"
else
    echo "監査ログ用RSA秘密鍵は既に存在します: $PRIV_KEY_PATH"
fi

# 監査ログ用の公開鍵を生成
if [ ! -f "$PUB_KEY_PATH" ]; then
    mkdir -p "$(dirname "$PUB_KEY_PATH")"
    openssl rsa -in "$PRIV_KEY_PATH" -pubout -out "$PUB_KEY_PATH"
    chmod 644 "$PUB_KEY_PATH"
    echo "監査ログ用RSA公開鍵を生成しました: $PUB_KEY_PATH"
else
    echo "監査ログ用RSA公開鍵は既に存在します: $PUB_KEY_PATH"
fi

# === PrivacyIDEA暗号化キーファイルの生成（公式entrypoint.py準拠） ===
PRIVACYIDEA_CERT_DIR="privacyidea/certs"
mkdir -p $PRIVACYIDEA_CERT_DIR

# PrivacyIDEA用の暗号化キーファイルを生成（公式実装準拠：96バイトのランダムキー）
# 参考: https://github.com/gpappsoft/privacyidea-docker/blob/main/entrypoint.py
if [ ! -f "$PRIVACYIDEA_CERT_DIR/enckey" ] || [ ! -s "$PRIVACYIDEA_CERT_DIR/enckey" ]; then
    # PI_ENCKEY環境変数が設定されている場合はそれを使用（公式実装準拠）
    if [ -n "$PI_ENCKEY" ]; then
        python3 -c "
import os
import base64
import pathlib

# PI_ENCKEY環境変数からBase64デコードして使用
enc_file = pathlib.Path('$PRIVACYIDEA_CERT_DIR/enckey')
with open(enc_file, 'wb') as f:
    f.write(base64.b64decode(os.environ['PI_ENCKEY']))
enc_file.chmod(0o400)
print('PI_ENCKEY環境変数から暗号化キーを生成しました: $PRIVACYIDEA_CERT_DIR/enckey')
"
    else
        # PI_ENCKEYが未設定の場合は新規生成
        python3 -c "
import os
import secrets
import pathlib

# 公式entrypoint.py準拠：DefaultSecurityModule.random(96)と同等の処理
enc_file = pathlib.Path('$PRIVACYIDEA_CERT_DIR/enckey')
with open(enc_file, 'wb') as f:
    f.write(secrets.token_bytes(96))
enc_file.chmod(0o400)
print('新しい暗号化キーを生成しました: $PRIVACYIDEA_CERT_DIR/enckey')
"
    fi
else
    echo "PrivacyIDEA暗号化キーファイルは既に存在します: $PRIVACYIDEA_CERT_DIR/enckey"
fi

# === PrivacyIDEA設定用暗号化キー生成 ===
# 環境変数ベース設定用の暗号化キーを生成し、.env ファイルに出力します。

# PI_PEPPERとSECRET_KEYを生成
PI_PEPPER=$(python3 -c "import secrets; print(secrets.token_hex(16))")
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

echo "新しいPrivacyIDEA暗号化キーを生成しました:"
echo "PI_PEPPER: $PI_PEPPER"
echo "SECRET_KEY: $SECRET_KEY"

# .env ファイルが存在する場合、暗号化キーを更新
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    # 現在の日時をコメントに追加
    TIMESTAMP=$(date '+%Y年%m月%d日 %H:%M:%S')
    
    # PI_SECRET の更新
    if grep -q "^PI_SECRET=" "$ENV_FILE"; then
        # 一時ファイルを作成して古い値をコメントアウトし、新しい値を追加
        awk -v new_secret="$SECRET_KEY" -v timestamp="$TIMESTAMP" '
        /^PI_SECRET=/ {
            print "#" $0
            print "PI_SECRET=" new_secret "  # " timestamp " 生成"
            next
        }
        { print }
        ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        echo ".env ファイルの PI_SECRET を更新しました"
    else
        echo "PI_SECRET=$SECRET_KEY  # $TIMESTAMP 生成" >> "$ENV_FILE"
        echo ".env ファイルに PI_SECRET を追加しました"
    fi
    
    # PI_PEPPER の更新
    if grep -q "^PI_PEPPER=" "$ENV_FILE"; then
        # 一時ファイルを作成して古い値をコメントアウトし、新しい値を追加
        awk -v new_pepper="$PI_PEPPER" -v timestamp="$TIMESTAMP" '
        /^PI_PEPPER=/ {
            print "#" $0
            print "PI_PEPPER=" new_pepper "  # " timestamp " 生成"
            next
        }
        { print }
        ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        echo ".env ファイルの PI_PEPPER を更新しました"
    else
        echo "PI_PEPPER=$PI_PEPPER  # $TIMESTAMP 生成" >> "$ENV_FILE"
        echo ".env ファイルに PI_PEPPER を追加しました"
    fi
else
    echo "⚠️  .env ファイルが見つかりません。手動で設定してください:"
    echo "PI_SECRET=$SECRET_KEY"
    echo "PI_PEPPER=$PI_PEPPER"
fi

echo ""
echo "=== 生成されたファイル一覧 ==="
echo "CA証明書（マスター）: $WEB_CERT_DIR/ca.crt"
echo "Webサーバ証明書（CN=\"${WEB_SERVER_CN}\"）: $WEB_CERT_DIR/server.crt"
echo "Webサーバ秘密鍵: $WEB_CERT_DIR/server.key"
echo "RADIUSサーバ証明書（CN=\"${RADIUS_CN}\"）: $RADIUS_CERT_DIR/radius.crt"
echo "RADIUSサーバ秘密鍵: $RADIUS_CERT_DIR/radius.key"
echo "RADIUS CA証明書（ハードリンク）: $RADIUS_CERT_DIR/ca.crt -> $WEB_CERT_DIR/ca.crt"
echo "PrivacyIDEA暗号化キー: $PRIVACYIDEA_CERT_DIR/enckey"
echo "PrivacyIDEA監査ログ秘密鍵: $PRIV_KEY_PATH"
echo "PrivacyIDEA監査ログ公開鍵: $PUB_KEY_PATH"

echo ""
echo "=== 生成仕様 ==="
echo "暗号化キー: 公式entrypoint.py準拠（96バイト）"
echo "監査ログ署名: RSA 4096bit"
echo "証明書暗号化: ECDSA P-384"
echo "証明書有効期限: 10年間"
echo "CA証明書管理: ハードリンク方式（nginx/certs/ca.crtと完全に同一ファイル）"

echo ""
echo "⚠️  重要: 暗号化キーが生成/更新されました"
echo "   - 既存の暗号化データは復号化できなくなる可能性があります"
echo "   - PrivacyIDEA起動後、必要に応じて設定を再度行ってください"
echo "   - RADIUSのCA証明書はハードリンクとして管理されます"
echo ""
echo "=== 生成されたファイルの詳細情報 ==="
echo "※ハードリンクは同一inode番号で識別できます"
find . -name '*pem' -o -name '*key' -o -name '*crt' | sort | xargs ls -ila
echo ""
echo "✅ 証明書・暗号化キー生成完了 ($(date))"
echo "📖 参考: https://github.com/gpappsoft/privacyidea-docker/blob/main/entrypoint.py"
