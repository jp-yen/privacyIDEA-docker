#!/bin/bash

# RADIUS通信テストスクリプト
# 使用方法: ./test_radius.sh [ユーザー名] [パスワード] [サーバー] [ポート] [共有秘密]

USERNAME=${1:-"testuser"}
PASSWORD=${2:-"testpass"}
SERVER=${3:-"freeradius"}
PORT=${4:-"1812"}
SECRET=${5:-"testing123"}

echo "=== RADIUS通信テスト ==="
echo "サーバー: $SERVER:$PORT"
echo "ユーザー: $USERNAME"
echo "========================="

# Access-Requestを送信
echo "Access-Requestを送信中..."
radtest "$USERNAME" "$PASSWORD" "$SERVER" "$PORT" "$SECRET"

echo ""
echo "テスト完了"
