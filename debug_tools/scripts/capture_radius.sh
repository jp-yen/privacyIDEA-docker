#!/bin/bash

# パケットキャプチャスクリプト
# RADIUSトラフィックをキャプチャする

INTERFACE=${1:-"eth0"}
FILTER=${2:-"port 1812 or port 1813"}
OUTPUT_FILE=${3:-"/debug/logs/radius_capture_$(date +%Y%m%d_%H%M%S).pcap"}

echo "=== RADIUSパケットキャプチャ ==="
echo "インターフェース: $INTERFACE"
echo "フィルター: $FILTER"
echo "出力ファイル: $OUTPUT_FILE"
echo "==============================="
echo ""
echo "キャプチャを開始します... (Ctrl+Cで停止)"

# tcpdumpでパケットをキャプチャ
tcpdump -i "$INTERFACE" -w "$OUTPUT_FILE" "$FILTER"

echo ""
echo "キャプチャファイル: $OUTPUT_FILE"
echo "ファイルサイズ: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
