#!/bin/bash

# PostgreSQL接続テストスクリプト
# PostgreSQLデータベースへの接続と基本的なクエリテストを行う

HOST=${1:-"postgres"}
PORT=${2:-"5432"}
DATABASE=${3:-"privacyidea"}
USERNAME=${4:-"${POSTGRES_USER}"}
PASSWORD=${5:-"${POSTGRES_PASSWORD}"}

echo "=== PostgreSQL接続テスト ==="
echo "ホスト: $HOST:$PORT"
echo "データベース: $DATABASE"
echo "ユーザー: $USERNAME"
echo "=========================="

# 接続テスト
echo "1. 接続テスト..."
export PGPASSWORD="$PASSWORD"

if psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" -c "\q" 2>/dev/null; then
    echo "✓ 接続成功"
else
    echo "✗ 接続失敗"
    exit 1
fi

# データベース一覧の取得
echo ""
echo "2. データベース一覧..."
psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" -c "\l"

echo ""
echo "3. テーブル一覧..."
psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" -c "\dt"

echo ""
echo "4. PrivacyIDEA関連テーブルの確認..."
psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%token%' OR table_name LIKE '%user%';"

echo ""
echo "テスト完了"
