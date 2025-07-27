# 設定ファイル詳細ガイド

## 概要

このドキュメントでは、FreeRADIUS-privacyIDEA Docker環境の各設定ファイルについて詳しく説明します。

## 環境設定ファイル

### .env

プロジェクト全体の環境変数を定義するファイルです。

```bash
# データベース設定
DB_USER=pi                           # PostgreSQLユーザー名
DB_PASSWORD=your_secure_password     # PostgreSQLパスワード（要変更）

# PrivacyIDEA設定
PI_ADMIN_PASS=your_admin_password    # 管理者パスワード（要変更）
PI_PASSWORD=your_pi_password         # APIパスワード（要変更）
PI_PEPPER=your_pepper_32chars        # 暗号化ペッパー（要変更、32文字以上）

# RADIUS設定
RADIUS_SECRET=your_radius_secret     # RADIUS共有シークレット（要変更）
```

**重要事項**:
- 本番環境では必ずすべてのパスワードを変更
- `PI_PEPPER`は32文字以上のランダム文字列
- `.env`ファイルは`.gitignore`で除外済み

## PrivacyIDEA設定

### privacyidea/conf/pi.cfg

PrivacyIDEAのメイン設定ファイルです。

```python
# PrivacyIDEA Configuration
# 公式設定を参考にした環境変数ベース動的設定

import logging
import os

pi_os_special_vars = {
    'SUPERUSER_REALM': os.getenv("SUPERUSER_REALM","admin,helpdesk").split(','),
    'PI_ENCFILE': '/data/certs/enckey',                          # 暗号化キーファイル
    'PI_SCRIPT_HANDLER_DIRECTORY': '/privacyidea/scripts',
    'PI_AUDIT_KEY_PRIVATE': '/data/certs/private.pem',          # 監査ログ秘密鍵
    'PI_AUDIT_KEY_PUBLIC': '/data/certs/public.pem',            # 監査ログ公開鍵
    'PI_AUDIT_SQL_TRUNCATE': os.getenv("PI_AUDIT_SQL_TRUNCATE", True),
    'PI_ENGINE_REGISTRY_CLASS': "shared",
    'PI_AUDIT_POOL_SIZE': "20",
    'PI_AUDIT_NO_SIGN': True,                                   # 監査ログ署名無効化
    'PI_LOGCONFIG': '/privacyidea/etc/logging.cfg',
    'PI_LOGLEVEL': logging.getLevelName("INFO"),
}

# データベース接続設定
SQLALCHEMY_DATABASE_URI = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@postgres/privacyidea"

# セキュリティ設定
SECRET_KEY = os.getenv('SECRET_KEY')                            # Flaskセッション暗号化キー
PI_PEPPER = os.getenv('PI_PEPPER')                             # パスワード暗号化ペッパー

# 管理者設定
SUPERUSER_REALM = ['admin', 'helpdesk']
```

**設定ポイント**:
- 環境変数を活用して機密情報をコード外で管理
- `PI_ENCFILE`は暗号化キーの保存場所（重要）
- `PI_AUDIT_NO_SIGN`でパフォーマンス向上

## FreeRADIUS設定

### freeradius/conf/clients.conf

RADIUSクライアントの定義ファイルです。

```bash
# FreeRADIUS Client Configuration

# デフォルトクライアント設定
client default {
    ipaddr = 0.0.0.0/0                    # 全IPからの接続を許可（開発用）
    secret = change_this_radius_secret     # 共有シークレット（要変更）
    require_message_authenticator = yes    # Message-Authenticator必須
    nas_type = other                       # NASタイプ
}

# ローカルホスト設定
client localhost {
    ipaddr = 127.0.0.1
    secret = change_this_radius_secret
    require_message_authenticator = yes
}

# 特定サブネット設定例
client internal_network {
    ipaddr = 192.168.0.0/24
    secret = change_this_radius_secret
    require_message_authenticator = yes
}
```

**セキュリティ考慮事項**:
- 本番環境では`ipaddr`を制限
- 強力な`secret`を設定
- `require_message_authenticator = yes`でセキュリティ強化

### freeradius/conf/radiusd.conf

FreeRADIUSのメイン設定ファイルです。

```bash
# FreeRADIUS Main Configuration

# 基本設定
prefix = /opt
exec_prefix = ${prefix}
sysconfdir = ${prefix}/etc
localstatedir = ${prefix}/var
sbindir = ${exec_prefix}/sbin
logdir = ${localstatedir}/log/radius
raddbdir = ${sysconfdir}/raddb

# ネットワーク設定
hostname_lookups = no
max_request_time = 30
cleanup_delay = 5
max_requests = 16384

# ログ設定
log {
    destination = files
    file = ${logdir}/radius.log
    syslog_facility = daemon
    stripped_names = no
    auth = yes
    auth_badpass = yes
    auth_goodpass = yes
    colourise = yes
}

# セキュリティ設定
checkrad = ${sbindir}/checkrad
security {
    max_attributes = 200
    reject_delay = 1
    status_server = yes
}
```

## Nginx設定

### nginx/conf/default.conf

リバースプロキシとSSL終端の設定です。

```nginx
# Nginx Configuration for PrivacyIDEA

upstream privacyidea {
    server privacyidea:8080;
}

# HTTP -> HTTPS リダイレクト
server {
    listen 80;
    server_name _;
    return 301 https://$server_name$request_uri;
}

# HTTPS サーバー設定
server {
    listen 443 ssl http2;
    server_name _;

    # SSL証明書設定
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_trusted_certificate /etc/nginx/certs/ca.crt;

    # SSL設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;

    # セキュリティヘッダー
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # PrivacyIDEAプロキシ設定
    location / {
        proxy_pass http://privacyidea;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Docker Compose設定

### docker-compose.yml

本番環境用のサービス定義です。

```yaml
services:
  postgres:
    image: postgres:17.5-alpine
    container_name: PostgreSQL
    environment:
      POSTGRES_DB: privacyidea
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./postgresql/data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d privacyidea"]
      interval: 2s
      timeout: 1s
      retries: 10

  privacyidea:
    image: gpappsoft/privacyidea-docker:3.11.3
    container_name: PrivacyIDEA
    env_file: .env
    volumes:
      - ./privacyidea/certs:/data/certs
      - ./privacyidea/conf/pi.cfg:/privacyidea/etc/pi.cfg:ro
    depends_on:
      postgres:
        condition: service_healthy

  nginx:
    image: nginx:1.28.0-alpine
    container_name: nginx
    volumes:
      - ./nginx/conf/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/certs:/etc/nginx/certs
    ports:
      - "80:80"
      - "443:443"

  freeradius:
    image: gpappsoft/privacyidea-freeradius:3.4.3-2
    container_name: FreeRADIUS
    env_file: .env
    volumes:
      - ./freeradius/conf/clients.conf:/opt/etc/raddb/clients.conf:ro
      - ./freeradius/certs:/opt/etc/raddb/certs:ro
    ports:
      - "1812:1812/udp"
      - "1813:1813/udp"
```

### デバッグモード（Docker Composeプロファイル）

デバッグ環境はDocker Composeのプロファイル機能を使用して実現されます：

- **通常モード**: `make up` → `privacyidea`, `freeradius`, `nginx`, `postgres`
- **デバッグモード**: `make debug-up` → `privacyidea-debug`, `freeradius-debug`, `nginx-debug`, `debug_tools`, `postgres`

デバッグモードの特徴：
- Flask Debug モード有効（`FLASK_DEBUG=true`）
- PrivacyIDEA詳細ログ（`PI_LOGLEVEL=10`）
- FreeRADIUSデバッグ出力（`freeradius -X`）
- debug_toolsコンテナでデバッグツール利用可能

## 証明書設定

### 自動生成される証明書

`make init-certs`で以下の証明書が生成されます：

```
nginx/certs/
├── ca.crt          # CA証明書
├── ca.key          # CA秘密鍵
├── server.crt      # Webサーバー証明書
└── server.key      # Webサーバー秘密鍵

freeradius/certs/
├── ca.crt          # CA証明書
├── radius.crt      # RADIUS証明書
└── radius.key      # RADIUS秘密鍵

privacyidea/certs/
├── enckey          # 暗号化キー（重要）
├── private.pem     # 監査ログ秘密鍵
└── public.pem      # 監査ログ公開鍵
```

**重要**: `privacyidea/certs/enckey`は絶対に削除・変更しないでください。

## 設定の検証

### 設定ファイルの構文チェック

```bash
# Docker Compose設定の検証
docker compose config

# Nginx設定の検証
docker compose exec nginx nginx -t

# PostgreSQL接続テスト
docker compose exec postgres psql -U ${DB_USER} -d privacyidea -c "SELECT version();"
```

### 設定の動作確認

```bash
# サービス状態確認
make status

# 認証テスト
make test-auth

# ログ確認
make logs
```

## トラブルシューティング

### よくある設定問題

1. **環境変数が反映されない**
   - `.env`ファイルの形式を確認
   - コンテナを再起動

2. **暗号化キーエラー**
   - `privacyidea/certs/enckey`の存在確認
   - ファイル権限の確認

3. **データベース接続エラー**
   - PostgreSQLコンテナの起動確認
   - 環境変数の値確認

4. **RADIUS認証失敗**
   - `clients.conf`の共有シークレット確認
   - ネットワーク接続の確認

詳細なトラブルシューティングは[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)を参照してください。

## nginx設定

### 基本設定ファイル

#### nginx/conf/default.conf

nginxのメイン設定ファイルです。リバースプロキシとしてprivacyIDEAにリクエストを転送します。

```nginx
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    # SSL証明書設定
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_trusted_certificate /etc/nginx/certs/ca.crt;

    # SSL設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # セキュリティヘッダー
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # プロキシ設定
    location / {
        proxy_pass http://privacyidea:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # タイムアウト設定
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### アクセス制限設定

#### IPアドレス制限

特定のIPアドレスやネットワークからのアクセスのみを許可する設定：

```nginx
server {
    listen 80;
    listen 443 ssl;
    
    # 基本的なIP制限
    allow 192.168.1.0/24;      # 内部ネットワーク
    allow 10.0.0.0/8;          # プライベートネットワーク
    allow 172.16.0.0/12;       # プライベートネットワーク
    allow 203.0.113.10;        # 特定のパブリックIP
    deny all;                  # その他すべて拒否
    
    # 管理者専用パスへの追加制限
    location /admin {
        allow 192.168.1.100;    # 管理者のIPのみ
        deny all;
        proxy_pass http://privacyidea:8080;
    }
    
    # 一般ユーザー向けパス
    location / {
        proxy_pass http://privacyidea:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 地理的制限（GeoIPモジュール使用）

国別でアクセス制限を行う設定：

```bash
# GeoIPデータベースのダウンロード
mkdir -p nginx/geoip
cd nginx/geoip
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb
```

```nginx
# nginx.confのhttpセクションに追加
http {
    geoip2 /etc/nginx/geoip/GeoLite2-Country.mmdb {
        auto_reload 5m;
        $geoip2_metadata_country_build metadata country_build;
        $geoip2_data_country_code default=US source=$remote_addr country iso_code;
        $geoip2_data_country_name source=$remote_addr country names en;
    }
    
    # 日本とアメリカのみ許可
    map $geoip2_data_country_code $allowed_country {
        default 0;
        JP 1;
        US 1;
    }
}

server {
    # 国別アクセス制限
    if ($allowed_country = 0) {
        return 403 "Access denied from your country";
    }
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

#### 時間帯制限

営業時間外のアクセス制限設定：

```nginx
server {
    # 営業時間外のアクセス制限（日本時間9:00-18:00のみ許可）
    set $time_allowed 0;
    if ($time_iso8601 ~ "T(09|10|11|12|13|14|15|16|17):") {
        set $time_allowed 1;
    }
    
    # 営業時間外は管理者IPのみ許可
    set $access_control "${time_allowed}${remote_addr}";
    if ($access_control ~ "^0(?!192\.168\.1\.100)") {
        return 403 "Access denied outside business hours";
    }
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

### レート制限設定

#### DDoS攻撃対策

アクセス頻度を制限する設定：

```nginx
# nginx.confのhttpセクションに追加
http {
    # レート制限ゾーンの定義
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;    # ログイン：5回/分
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;     # API：10回/秒
    limit_req_zone $binary_remote_addr zone=general:10m rate=2r/s;  # 一般：2回/秒
    
    # 接続数制限
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
}

server {
    # 全体の接続数制限
    limit_conn conn_limit_per_ip 10;
    
    # ログインページのレート制限
    location /auth {
        limit_req zone=login burst=3 nodelay;
        proxy_pass http://privacyidea:8080;
    }
    
    # API呼び出しのレート制限
    location /api {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://privacyidea:8080;
    }
    
    # その他のページのレート制限
    location / {
        limit_req zone=general burst=10 nodelay;
        proxy_pass http://privacyidea:8080;
    }
}
```

### User-Agentフィルタリング

#### ボット・スクレイパー対策

悪意のあるUser-Agentをブロックする設定：

```nginx
server {
    # 悪意のあるUser-Agentをブロック
    if ($http_user_agent ~* (bot|crawler|spider|scraper|scanner|nikto|sqlmap)) {
        return 403 "Bot access denied";
    }
    
    # 空のUser-Agentをブロック
    if ($http_user_agent = "") {
        return 403 "Missing User-Agent";
    }
    
    # 特定のUser-Agentのみ許可（より厳しい制限）
    set $allowed_ua 0;
    if ($http_user_agent ~* (Mozilla|Chrome|Firefox|Safari|Edge)) {
        set $allowed_ua 1;
    }
    if ($allowed_ua = 0) {
        return 403 "Unauthorized User-Agent";
    }
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

### セキュリティ強化設定

#### HTTPS強制とセキュリティヘッダー

```nginx
server {
    # HTTPからHTTPSへのリダイレクト強制
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
    
    # セキュリティヘッダーの追加
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'" always;
    
    # 特定のファイルへのアクセス禁止
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(sql|bak|backup|old|tmp)$ {
        deny all;
    }
    
    # robots.txtの設定
    location = /robots.txt {
        add_header Content-Type text/plain;
        return 200 "User-agent: *\nDisallow: /\n";
    }
    
    location / {
        proxy_pass http://privacyidea:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 設定の適用

#### 設定ファイルの検証と適用

```bash
# 設定ファイルのバックアップ
cp nginx/conf/default.conf nginx/conf/default.conf.backup

# 設定変更後の構文チェック
docker compose exec nginx nginx -t

# 設定の適用（nginxの再起動）
docker compose restart nginx

# または、設定のリロード（ダウンタイムなし）
docker compose exec nginx nginx -s reload
```

#### 設定のテスト

```bash
# 基本アクセステスト
curl -I http://localhost/

# HTTPS リダイレクトテスト
curl -I http://localhost/ | grep -i location

# IP制限テスト（偽装ヘッダー使用）
curl -I -H "X-Forwarded-For: 1.2.3.4" http://localhost/

# User-Agentフィルタリングテスト
curl -I -H "User-Agent: bot" http://localhost/

# レート制限テスト
for i in {1..10}; do curl -I http://localhost/; done
```

### 設定例集

#### 社内ネットワーク限定設定

```nginx
server {
    # 社内ネットワークのみ許可
    allow 192.168.0.0/16;
    allow 10.0.0.0/8;
    deny all;
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

#### VPN経由限定設定

```nginx
server {
    # VPNネットワークのみ許可
    allow 172.16.0.0/12;
    deny all;
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

#### 特定IPと時間制限の組み合わせ

```nginx
server {
    # 時間帯制限
    set $time_allowed 0;
    if ($time_iso8601 ~ "T(09|10|11|12|13|14|15|16|17):") {
        set $time_allowed 1;
    }
    
    # IP制限
    set $ip_allowed 0;
    if ($remote_addr ~ "^192\.168\.1\.") {
        set $ip_allowed 1;
    }
    
    # 両方の条件をチェック
    set $access_allowed "${time_allowed}${ip_allowed}";
    if ($access_allowed != "11") {
        return 403 "Access denied";
    }
    
    location / {
        proxy_pass http://privacyidea:8080;
    }
}
```

運用面でのnginx設定管理については、[OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md)を参照してください。
