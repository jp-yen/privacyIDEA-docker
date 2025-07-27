#!/bin/bash

# PrivacyIDEA API テストスクリプト
# PrivacyIDEAのREST APIの動作確認を行う

SERVER=${1:-"privacyidea:8080"}
ADMIN_USER=${2:-"admin"}
ADMIN_PASS=${3:-"admin"}

echo "=== PrivacyIDEA API テスト ==="
echo "サーバー: $SERVER"
echo "管理者: $ADMIN_USER"
echo "=========================="

BASE_URL="http://$SERVER"

# システム情報の取得
echo "1. システム情報の取得..."
curl -s -X GET "$BASE_URL/info" | jq '.' 2>/dev/null || echo "JSONパースエラー"

echo ""
echo "2. 認証テスト..."
# 管理者でログイン（認証トークンを取得）
AUTH_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$ADMIN_USER&password=$ADMIN_PASS" \
    "$BASE_URL/auth")

if echo "$AUTH_RESPONSE" | grep -q "access_token"; then
    echo "✓ 認証成功"
    TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.result.value.token' 2>/dev/null)
    echo "トークン: ${TOKEN:0:20}..."
else
    echo "✗ 認証失敗"
    echo "レスポンス: $AUTH_RESPONSE"
fi

echo ""
echo "3. システムステータスの確認..."
if [ ! -z "$TOKEN" ]; then
    curl -s -X GET \
        -H "Authorization: $TOKEN" \
        "$BASE_URL/system" | jq '.' 2>/dev/null || echo "JSONパースエラー"
else
    echo "認証トークンがないためスキップ"
fi

echo ""
echo "テスト完了"
