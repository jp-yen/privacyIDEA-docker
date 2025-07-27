#!/bin/bash

# ネットワーク接続テストスクリプト
# 各サービスへの接続確認を行う

echo "=== ネットワーク接続テスト ==="

# 各サービスの接続確認
services=(
    "postgres:5432"
    "privacyidea:8080"
    "nginx:80"
    "nginx:443"
    "freeradius:1812"
    "freeradius:1813"
)

for service in "${services[@]}"; do
    host=$(echo $service | cut -d':' -f1)
    port=$(echo $service | cut -d':' -f2)
    
    echo -n "[$host:$port] "
    if nc -z -w5 "$host" "$port" 2>/dev/null; then
        echo "✓ 接続可能"
    else
        echo "✗ 接続不可"
    fi
done

echo ""
echo "=== DNS解決テスト ==="
hosts=("postgres" "privacyidea" "nginx" "freeradius")

for host in "${hosts[@]}"; do
    echo -n "[$host] "
    if nslookup "$host" >/dev/null 2>&1; then
        ip=$(nslookup "$host" | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | tail -1)
        echo "✓ 解決可能 ($ip)"
    else
        echo "✗ 解決不可"
    fi
done

echo ""
echo "テスト完了"
