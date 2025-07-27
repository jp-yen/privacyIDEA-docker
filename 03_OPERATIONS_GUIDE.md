# FreeRADIUS-privacyIDEA (Docker) 運用ガイド

## 概要

このドキュメントは、FreeRADIUS-privacyIDEA Dockerシステムの日常運用、メンテナンス、トラブルシューティングに関する詳細な手順を説明します。

## 前提条件

- システムが正常にデプロイ済み（[01_DEPLOYMENT_GUIDE.md](01_DEPLOYMENT_GUIDE.md)参照）
- 基本的なDockerとDocker Composeの知識
- システム管理者権限

## 日常運用

### Makefileによる統合管理

このプロジェクトでは、運用を簡素化するためのMakefileを提供しています：

```bash
# ヘルプ表示
make help

# サービス制御
make up                  # サービス起動（本番モード）
make stop                # サービス停止
make restart             # サービス再起動
make status              # コンテナ状態確認

# デバッグモード制御
make debug-up            # デバッグモードで起動（プロファイルベース: privacyidea-debug、freeradius-debug、debug_tools有効）
make debug-down          # デバッグモードを停止し通常モードに戻る
make debug-shell         # デバッグツールシェルに接続

# ログ管理
make logs                # 全サービスログ表示
make freeradius-logs     # FreeRADIUSログ（リアルタイム）
make freeradius-logs-recent  # FreeRADIUSの最新ログ

# テスト
make test-auth           # RADIUS認証テスト

# メンテナンス
make update-certs        # 証明書更新
make clean-data          # データと証明書をクリア
make clean-all           # すべてのリソースを削除
```

### サービス状態の監視

#### 基本的な状態確認

```bash
# コンテナの状態確認
make status

# 詳細な状態確認
docker compose ps

# リソース使用状況確認
docker compose top
docker stats
```

#### ヘルスチェック

```bash
# ヘルスチェック状況の確認
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# 個別サービスの詳細確認
docker inspect $(docker compose ps -q privacyidea) | grep -A 10 Health
```

#### ログの監視

```bash
# リアルタイムログ監視
make logs

# 特定サービスのログ
docker compose logs -f privacyidea
docker compose logs -f freeradius
docker compose logs -f postgres
docker compose logs -f nginx

# エラーログのみ抽出
docker compose logs | grep -i error
docker compose logs | grep -i warning
```

## バックアップ管理

バックアップとリストアの詳細な手順については、**[04_BACKUP_GUIDE.md](04_BACKUP_GUIDE.md)**を参照してください。

### 日常的なバックアップ確認

```bash
# バックアップファイルの確認
ls -la backups/

# 最新バックアップの確認
ls -lt backups/ | head -5

# バックアップ実行状況の確認
crontab -l | grep backup
```

## 証明書管理

### SSL/TLS証明書の更新

#### 自己署名証明書の再生成

```bash
# 既存証明書の確認
ls -la nginx/certs/
openssl x509 -in nginx/certs/server.crt -text -noout | grep -A 2 Validity

# 証明書の再生成
make update-certs

# サービスの再起動
make restart
```

#### Let's Encrypt証明書の使用

```bash
# Let's Encrypt証明書の取得（例）
certbot certonly --standalone -d your-domain.com

# 証明書の配置
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/certs/server.crt
cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/certs/server.key

# nginxの再起動
docker compose restart nginx
```

#### 証明書の自動更新

```bash
# Let's Encrypt自動更新スクリプト（例）
cat > /etc/cron.monthly/update-ssl-certs.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /path/to/project/nginx/certs/server.crt
cp /etc/letsencrypt/live/your-domain.com/privkey.pem /path/to/project/nginx/certs/server.key
cd /path/to/project && docker compose restart nginx
EOF

chmod +x /etc/cron.monthly/update-ssl-certs.sh
```

## nginxアクセス制限

### 設定ファイルの管理

nginx設定ファイルの詳細な編集方法については、**[02_CONFIGURATION.md](02_CONFIGURATION.md)**を参照してください。

### 設定の適用と検証

```bash
# nginx設定の構文チェック
docker compose exec nginx nginx -t

# 設定変更の適用
docker compose restart nginx

# アクセス制限のテスト
curl -I http://localhost/  # 許可されたIPから
curl -I -H "X-Forwarded-For: 1.2.3.4" http://localhost/  # 拒否されるIPから

# ログでアクセス状況を確認
docker compose logs nginx | grep -E "(403|denied)"
```

### アクセス制限ログの監視

```bash
# nginx アクセスログの確認
docker compose logs nginx | tail -50

# 拒否されたアクセスの統計
docker compose logs nginx | grep " 403 " | awk '{print $1}' | sort | uniq -c | sort -nr

# 特定期間のアクセス状況分析
docker compose logs nginx --since=24h | grep -E "(403|denied)" | wc -l
```

### 動的IP制限の監視

```bash
# nginx-module-vtsを使用した動的制限（高度な設定）
# カスタムログ形式での監視
cat > scripts/monitor_failed_access.sh << 'EOF'
#!/bin/bash
# 過去5分間で3回以上失敗したIPを一時的にブロック

LOG_FILE="/var/log/nginx/access.log"
BLOCKED_IPS_FILE="/tmp/blocked_ips.txt"

# 失敗したアクセスのIPを抽出
awk '$9 ~ /40[0-9]/ {print $1}' $LOG_FILE | \
sort | uniq -c | awk '$1 >= 3 {print $2}' > $BLOCKED_IPS_FILE

# iptablesでブロック（例）
while read ip; do
    iptables -A INPUT -s $ip -j DROP
done < $BLOCKED_IPS_FILE
EOF

chmod +x scripts/monitor_failed_access.sh

# crontabに追加（5分毎実行）
echo "*/5 * * * * /path/to/project/scripts/monitor_failed_access.sh" | crontab -
```

## 暗号化キー管理

### 重要な注意事項

**⚠️ 警告**: 暗号化キー（SECRET_KEY、PI_PEPPER、enckey）を変更すると、既存の認証データ（2FA情報等）が復号化できなくなります。

### キーの確認と検証

```bash
# 現在の暗号化キーを確認
grep -E "SECRET_KEY|PI_PEPPER" privacyidea/conf/pi.cfg
ls -la privacyidea/certs/enckey
stat privacyidea/certs/enckey

# キーファイルの整合性確認
md5sum privacyidea/certs/enckey
```

### キーのバックアップ

```bash
# 暗号化キーの安全なバックアップ
tar -czf encryption_keys_backup_$(date +%Y%m%d).tar.gz \
  privacyidea/certs/enckey \
  privacyidea/certs/private.pem \
  privacyidea/certs/public.pem

# バックアップの暗号化（推奨）
gpg --symmetric --cipher-algo AES256 encryption_keys_backup_*.tar.gz
rm encryption_keys_backup_*.tar.gz  # 元ファイルを削除

# 安全な場所に保存
mv encryption_keys_backup_*.tar.gz.gpg /secure/backup/location/
```

## TOTP（2要素認証）の運用

### ユーザー管理

#### TOTPトークンの登録

```bash
# privacyIDEA Web UIでの操作手順:
# 1. http://localhost にアクセス
# 2. 管理者でログイン
# 3. Users → User Details でユーザー作成
# 4. Tokens → Assign Token でTOTPトークンを割り当て
# 5. QRコードを提供してユーザーに登録依頼
```

#### 一括ユーザー作成

```bash
# CSVファイルでの一括インポート（例）
cat > users_import.csv << 'EOF'
username,email,givenname,surname
user01,user01@example.com,User,One
user02,user02@example.com,User,Two
EOF

# privacyIDEA Web UIでインポート:
# Users → Import Users → CSV File Upload
```

### TOTP認証テスト

#### デバッグ環境でのテスト

```bash
# デバッグ環境起動
make debug-up

# デバッグコンテナに接続
make debug-shell

# TOTP認証テスト（ユーザー、パスワード、TOTPコード、サーバー）
/debug/scripts/test_radius_totp.pl user01 pass01 123456 freeradius

# 外部サーバーへのテスト
/debug/scripts/test_radius_totp.pl user01 pass01 123456 192.168.1.100 1812

# デバッグ環境終了
exit
make debug-down
```

#### 本番環境でのテスト

```bash
# 基本認証テスト（第1段階のみ）
make test-auth

# radclientを使った詳細テスト
echo "User-Name=user01,User-Password=pass01123456" | \
radclient -x localhost:1812 auth testing123

# Challenge-Response認証テスト（TOTP利用時）
# 1. チャレンジ取得
curl -X POST "http://localhost:8080/validate/check" -d "user=user01&pass=pass01"

# 2. 取得したtransaction_idとTOTPコードで認証
# curl -X POST "http://localhost:8080/validate/check" -d "user=user01&transaction_id=XXX&pass=123456"
```

## システムメンテナンス

### 定期メンテナンス作業

#### 毎日の作業

```bash
# システム状態確認
make status

# ログエラーチェック
docker compose logs --since=24h | grep -i error

# ディスク容量確認
df -h
du -sh postgresql/data/
```

#### 週次の作業

```bash
# ログのアーカイブとクリーンアップ
docker compose logs > logs/weekly_$(date +%Y%m%d).log

# 不要なDockerリソースの削除
docker system prune -f

# 証明書の有効期限確認
openssl x509 -in nginx/certs/server.crt -checkend 604800 && echo "Certificate OK" || echo "Certificate expires soon"
```

#### 月次の作業

```bash
# 完全バックアップの作成
./scripts/backup_database.sh monthly_backup_$(date +%Y%m)

# セキュリティアップデートの確認
docker compose pull
make restart

# パフォーマンス統計の確認
docker stats --no-stream > stats/monthly_$(date +%Y%m).txt
```

### ログ管理

#### ログローテーションの設定

```bash
# logrotateの設定
cat > /etc/logrotate.d/freeradius-privacyidea << 'EOF'
/path/to/project/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        docker compose restart
    endscript
}
EOF
```

#### ログ分析

```bash
# エラーログの分析
docker compose logs | grep -E "(ERROR|CRITICAL|FATAL)" | sort | uniq -c

# 認証失敗の分析
docker compose logs freeradius | grep "Access-Reject" | wc -l

# アクセス統計
docker compose logs nginx | awk '{print $1}' | sort | uniq -c | sort -nr
```

## トラブルシューティング

### パフォーマンス問題

#### リソース使用量の確認

```bash
# CPU・メモリ使用量
docker stats --no-stream

# ディスクI/O確認
iotop -ao

# ネットワークトラフィック
nethogs

# データベースのパフォーマンス確認
docker compose exec postgres pg_stat_activity
```

#### 最適化

```bash
# PostgreSQLの設定最適化
# postgresql/conf/postgresql.conf を編集:
# shared_buffers = 256MB
# effective_cache_size = 1GB
# max_connections = 100

# 設定変更後の再起動
docker compose restart postgres
```

### 接続問題

#### ネットワーク診断

```bash
# デバッグ環境での診断
make debug-up
make debug-shell

# サービス間通信確認
ping privacyidea
ping postgres
ping freeradius

# ポート確認
telnet privacyidea 8080
telnet postgres 5432
telnet freeradius 1812

# DNS解決確認
nslookup privacyidea
```

#### RADIUS認証問題

```bash
# FreeRADIUSデバッグモード
make debug-up

# デバッグログの確認
make freeradius-logs

# 設定ファイルの構文確認
docker compose exec freeradius radiusd -XC

# クライアント設定確認
cat freeradius/conf/clients.conf
```

### データベース問題

#### 接続確認

```bash
# PostgreSQL接続テスト
docker compose exec postgres pg_isready -U pi

# データベース内容確認
docker compose exec postgres psql -U pi -d privacyidea -c "\dt"

# 接続数確認
docker compose exec postgres psql -U pi -d privacyidea -c "SELECT count(*) FROM pg_stat_activity;"
```

#### データベースの最適化

```bash
# VACUUM実行
docker compose exec postgres psql -U pi -d privacyidea -c "VACUUM ANALYZE;"

# インデックスの再構築
docker compose exec postgres psql -U pi -d privacyidea -c "REINDEX DATABASE privacyidea;"

# データベースサイズ確認
docker compose exec postgres psql -U pi -d privacyidea -c "SELECT pg_size_pretty(pg_database_size('privacyidea'));"
```

## セキュリティ監査

### ログ監査

```bash
# 認証ログの確認
docker compose logs freeradius | grep -E "(Access-Accept|Access-Reject)" | tail -50

# 管理者ログインの確認
docker compose logs privacyidea | grep -i admin | tail -20

# 異常なアクセスパターンの検出
docker compose logs nginx | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
```

### 脆弱性チェック

```bash
# Dockerイメージの脆弱性スキャン
docker scout cves $(docker compose images -q)

# 設定ファイルの権限確認
find . -name "*.conf" -o -name "*.cfg" -o -name "enckey" | xargs ls -la

# パスワード設定の確認（暗号化されていることを確認）
grep -v "^#" .env | grep -i pass
```

## 災害復旧

### 完全復旧手順

```bash
# 1. 新しい環境でのデプロイ
git clone <repository-url>
cd FreeRADIUS-privacyIDEA_\(Docker\)

# 2. 設定ファイルの復元
tar -xzf config_backup_*.tar.gz

# 3. データベースの復元
./scripts/restore_database.sh backups/backup_*.sql

# 4. 暗号化キーの復元（復号化）
gpg --decrypt encryption_keys_backup_*.tar.gz.gpg | tar -xz

# 5. サービス起動
make up

# 6. 動作確認
make status
make test-auth
```

## パフォーマンス監視

### メトリクス収集

```bash
# システムメトリクス収集スクリプト
cat > scripts/collect_metrics.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
echo "=== $DATE ===" >> metrics/system_metrics.log
docker stats --no-stream >> metrics/system_metrics.log
docker compose logs --since=1h | grep -c "Access-Accept" >> metrics/auth_success.log
docker compose logs --since=1h | grep -c "Access-Reject" >> metrics/auth_failure.log
EOF

chmod +x scripts/collect_metrics.sh

# crontabに追加
echo "*/5 * * * * /path/to/project/scripts/collect_metrics.sh" | crontab -
```

## サポートとエスカレーション

### ログ収集

問題発生時の情報収集：

```bash
# 診断情報の自動収集
cat > scripts/collect_diagnostics.sh << 'EOF'
#!/bin/bash
DIAG_DIR="diagnostics_$(date +%Y%m%d_%H%M%S)"
mkdir -p $DIAG_DIR

# システム情報
docker version > $DIAG_DIR/docker_version.txt
docker compose version > $DIAG_DIR/compose_version.txt
uname -a > $DIAG_DIR/system_info.txt
df -h > $DIAG_DIR/disk_usage.txt

# サービス状態
docker compose ps > $DIAG_DIR/service_status.txt
docker compose logs --tail=1000 > $DIAG_DIR/service_logs.txt

# 設定ファイル（機密情報除外）
cp .env $DIAG_DIR/env_sanitized.txt
sed -i 's/PASSWORD=.*/PASSWORD=***REDACTED***/g' $DIAG_DIR/env_sanitized.txt

tar -czf $DIAG_DIR.tar.gz $DIAG_DIR/
rm -rf $DIAG_DIR/
echo "診断情報を $DIAG_DIR.tar.gz に保存しました"
EOF

chmod +x scripts/collect_diagnostics.sh
```

### エスカレーション手順

1. **ログの確認**: `make logs`
2. **診断情報の収集**: `./scripts/collect_diagnostics.sh`
3. **GitHubでのIssue作成**: 診断情報を添付
4. **緊急時の一時的な回避策**: サービス再起動、デバッグモード使用

このガイドは定期的に更新されます。最新版は常にGitHubリポジトリを参照してください。
