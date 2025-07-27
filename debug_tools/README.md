# Debug Tools コンテナ

このディレクトリ以下のファイルは、debug_tools コンテナに導入し、FreeRADIUS-PrivacyIDEA環境のデバッグと通信試験を行うためのツールを提供します。(直接使うものではありません)

## インストールされているツール

### ネットワーク関連
- `curl` - HTTP/HTTPS リクエスト送信
- `wget` - ファイルダウンロード
- `netcat-openbsd` (nc) - ネットワーク接続テスト
- `bind-tools` (nslookup, dig) - DNS 解決テスト
- `iputils` (ping) - ICMP ping テスト
- `traceroute` - ネットワーク経路追跡
- `tcpdump` - パケットキャプチャ
- `tshark` - Wireshark コマンドライン版
- `telnet` - Telnet 接続テスト
- `nmap` - ポートスキャン

### データベース・認証関連
- `freeradius-utils` - RADIUS クライアントツール (radtest, radclient等)
- `postgresql-client` (psql) - PostgreSQL クライアント
- `openldap-clients` (ldapsearch, ldapadd等) - LDAP クライアント

### プログラミング・スクリプト関連
- `perl` - Perl インタープリター
- `perl-file-temp` - セキュアな一時ファイル作成モジュール

### その他
- `jq` - JSON パーサー
- `bash` - 高機能シェル
- `vim` - マルチバイト対応viエディタ
- `openssh-client` - SSH クライアント
- `net-tools` - ネットワーク設定表示

## 使用方法

### デバッグ環境の起動
```bash
make debug-up
```

### デバッグ環境の停止
```bash
make debug-down
```

### デバッグコンテナに接続
```bash
make debug-shell
```
または
```bash
docker exec -it debug_tools bash
```

## 提供されているスクリプト

### 1. ネットワーク接続テスト
```bash
/debug/scripts/test_network.sh
```
各サービス（postgres, privacyidea, nginx, freeradius）への接続確認とDNS解決テストを実行します。

### 2. PostgreSQL接続テスト
```bash
/debug/scripts/test_postgresql.sh [ホスト] [ポート] [データベース] [ユーザー] [パスワード]
```
PostgreSQLデータベースへの接続と基本的なクエリテストを行います。

### 3. PrivacyIDEA APIテスト
```bash
/debug/scripts/test_privacyidea.sh [サーバー] [管理者ユーザー] [パスワード]
```
PrivacyIDEAのREST APIの動作確認を行います。

### 4. RADIUS通信テスト
```bash
/debug/scripts/test_radius.sh [ユーザー名] [パスワード] [サーバー] [ポート] [共有秘密]
```
RADIUSサーバーへの認証リクエスト送信テストを行います。

### 5. RADIUS TOTP認証テスト
```bash
/debug/scripts/test_radius_totp.pl [ユーザー名] [パスワード] [TOTPコード] [サーバー] [ポート]
```
TOTPを使用した2要素認証のテストを行います。clients.confから共有秘密を自動読み込みします。

### 6. LDAP接続テスト
```bash
/debug/scripts/test_ldap.sh [ホスト] [ポート] [ベースDN] [バインドDN] [パスワード]
```
LDAPサーバーへの接続と基本的な検索テストを行います。

### 7. パケットキャプチャ
```bash
/debug/scripts/capture_radius.sh [インターフェース] [フィルター] [出力ファイル]
```
RADIUSトラフィックをキャプチャしてpcapファイルに保存します。

### 8. 全体テスト
```bash
/debug/scripts/run_all_tests.sh
```
すべてのテストスクリプトを順次実行します。

## よく使用するコマンド例

### ネットワーク診断
```bash
# ping テスト
ping -c 3 postgres

# traceroute テスト
traceroute privacyidea

# ポート接続確認
nc -z freeradius 1812 && echo "RADIUS port open" || echo "RADIUS port closed"

# DNS解決確認
nslookup privacyidea
```

### RADIUS認証テスト
```bash
# 基本パスワード認証
radtest testuser testpass freeradius 1812 testing123

# 詳細出力付き
radtest -x testuser testpass freeradius 1812 testing123

# TOTP認証テスト
/debug/scripts/test_radius_totp.pl testuser mypass 123456

# 外部サーバーへのTOTPテスト
/debug/scripts/test_radius_totp.pl testuser mypass 123456 192.168.1.100 1812
```

### PostgreSQL操作
```bash
# データベース接続
psql -h postgres -U username -d privacyidea

# テーブル一覧表示
psql -h postgres -U username -d privacyidea -c "\dt"
```

### LDAP操作
```bash
# 匿名検索
ldapsearch -x -H ldap://ldap.example.com -b "dc=example,dc=com" "(objectclass=person)"

# 認証付き検索
ldapsearch -x -H ldap://ldap.example.com -D "cn=admin,dc=example,dc=com" -w password -b "dc=example,dc=com" "(uid=testuser)"
```

### HTTP API テスト
```bash
# PrivacyIDEA システム情報取得
curl -X GET http://privacyidea:8080/info | jq '.'

# nginx ステータス確認
curl -I http://nginx/
```

### パケット解析
```bash
# リアルタイムでRADIUSパケットを表示
tcpdump -i eth0 -n port 1812

# tsharkでより詳細な解析
tshark -i eth0 -f "port 1812" -V

# HTTPトラフィックの監視
tcpdump -i eth0 -A port 80
```

## ログファイル

キャプチャしたパケットやログは `/debug/logs/` ディレクトリに保存されます。

## 注意事項

- コンテナは他のサービスと同じネットワーク（pi-network）に接続されています
- パケットキャプチャにはroot権限が必要な場合があります
- 本番環境では使用しないでください（デバッグ専用）
