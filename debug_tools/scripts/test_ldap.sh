#!/bin/bash

# LDAP接続テストスクリプト
# LDAPサーバーへの接続と基本的な検索テストを行う

HOST=${1:-"ldap.example.com"}
PORT=${2:-"389"}
BASE_DN=${3:-"dc=example,dc=com"}
BIND_DN=${4:-"cn=admin,dc=example,dc=com"}
BIND_PW=${5:-"password"}

echo "=== LDAP接続テスト ==="
echo "ホスト: $HOST:$PORT"
echo "ベースDN: $BASE_DN"
echo "バインドDN: $BIND_DN"
echo "======================"

# 匿名接続テスト
echo "1. 匿名接続テスト..."
if ldapsearch -x -H "ldap://$HOST:$PORT" -b "$BASE_DN" -s base "(objectclass=*)" dn 2>/dev/null | grep -q "dn:"; then
    echo "✓ 匿名接続成功"
else
    echo "✗ 匿名接続失敗"
fi

# 認証接続テスト（バインドDNが指定されている場合）
if [ "$BIND_DN" != "cn=admin,dc=example,dc=com" ] && [ "$BIND_PW" != "password" ]; then
    echo ""
    echo "2. 認証接続テスト..."
    if ldapsearch -x -H "ldap://$HOST:$PORT" -D "$BIND_DN" -w "$BIND_PW" -b "$BASE_DN" -s base "(objectclass=*)" dn 2>/dev/null | grep -q "dn:"; then
        echo "✓ 認証接続成功"
        
        echo ""
        echo "3. ユーザー検索テスト..."
        ldapsearch -x -H "ldap://$HOST:$PORT" -D "$BIND_DN" -w "$BIND_PW" -b "$BASE_DN" "(objectclass=person)" cn mail | head -20
        
    else
        echo "✗ 認証接続失敗"
    fi
else
    echo ""
    echo "2. 認証接続テストをスキップ（デフォルト値のため）"
    echo "   使用方法: $0 <ホスト> <ポート> <ベースDN> <バインドDN> <パスワード>"
fi

echo ""
echo "テスト完了"
