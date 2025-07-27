#!/bin/bash
# スタティックリンクのtcpdumpビルドスクリプト
# Alpine Linux用に最適化

set -e

BUILD_DIR="/tmp/tcpdump_build"
OUTPUT_DIR="/debug/static_bins"

echo "=== スタティックリンクtcpdumpビルド開始 ==="

# ビルドディレクトリの準備
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"
cd "$BUILD_DIR"

echo "1. 必要なパッケージをインストール..."
apk update
apk add --no-cache \
    build-base \
    cmake \
    git \
    autoconf \
    automake \
    libtool \
    linux-headers \
    bison \
    flex \
    pkgconfig

echo "2. libpcapソースをダウンロード..."
wget https://www.tcpdump.org/release/libpcap-1.10.4.tar.gz
tar -xzf libpcap-1.10.4.tar.gz
cd libpcap-1.10.4

echo "3. libpcapをスタティックビルド..."
./configure --disable-shared --enable-static --disable-dbus --disable-usb --disable-bluetooth
make -j$(nproc)
make install
cd ..

echo "4. tcpdumpソースをダウンロード..."
wget https://www.tcpdump.org/release/tcpdump-4.99.4.tar.gz
tar -xzf tcpdump-4.99.4.tar.gz
cd tcpdump-4.99.4

echo "5. tcpdumpをスタティックビルド..."
LDFLAGS="-static" ./configure --disable-shared
make -j$(nproc)

echo "6. バイナリをコピー..."
cp tcpdump "$OUTPUT_DIR/tcpdump-static"
chmod +x "$OUTPUT_DIR/tcpdump-static"

echo "7. バイナリサイズとリンク情報を確認..."
ls -lh "$OUTPUT_DIR/tcpdump-static"
file "$OUTPUT_DIR/tcpdump-static"
ldd "$OUTPUT_DIR/tcpdump-static" 2>&1 || echo "スタティックリンクバイナリ: 動的ライブラリなし"

echo "8. 動作テスト..."
"$OUTPUT_DIR/tcpdump-static" --version

echo "=== ビルド完了 ==="
echo "バイナリ場所: $OUTPUT_DIR/tcpdump-static"

# クリーンアップ
cd /
rm -rf "$BUILD_DIR"

echo "=== スタティックtcpdumpが利用可能です ==="
