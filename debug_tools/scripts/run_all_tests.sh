#!/bin/bash

# 全体テストスクリプト
# 全てのテストを実行する

echo "=========================================="
echo "  FreeRADIUS-PrivacyIDEA 統合テスト"
echo "=========================================="
echo ""

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 各テストスクリプトを実行
echo "1. ネットワーク接続テスト"
echo "------------------------------------------"
bash "$SCRIPT_DIR/test_network.sh"

echo ""
echo "2. PostgreSQL接続テスト"
echo "------------------------------------------"
bash "$SCRIPT_DIR/test_postgresql.sh"

echo ""
echo "3. PrivacyIDEA APIテスト"
echo "------------------------------------------"
bash "$SCRIPT_DIR/test_privacyidea.sh"

echo ""
echo "4. RADIUS通信テスト"
echo "------------------------------------------"
bash "$SCRIPT_DIR/test_radius.sh"

echo ""
echo "5. LDAP接続テスト（オプション）"
echo "------------------------------------------"
echo "LDAPテストはデフォルトパラメータではスキップされます"
echo "必要に応じて: bash $SCRIPT_DIR/test_ldap.sh <ホスト> <ポート> <ベースDN> <バインドDN> <パスワード>"

echo ""
echo "=========================================="
echo "  全テスト完了"
echo "=========================================="
