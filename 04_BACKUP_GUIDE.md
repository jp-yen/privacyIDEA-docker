# バックアップ・リストアガイド

## 概要

このドキュメントでは、FreeRADIUS-privacyIDEA Docker環境のデータベースバックアップとリストアの詳細な手順について説明し### 対話型シェル
./scripts/db_management.sh shell
```

### 設定ファイルバックアップスクリプト

設定ファイルのバックアップは、データベースバックアップとは別に管理する必要があります。

#### 手動設定ファイルバックアップ

```bash
# 設定ファイルのバックアップ作成
tar -czf config_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  .env \
  docker-compose.yml \
  privacyidea/conf/ \
  freeradius/conf/ \
  nginx/conf/ \
  privacyidea/certs/enckey \
  privacyidea/certs/private.pem \
  privacyidea/certs/public.pem \
  nginx/certs/ \
  freeradius/certs/

# バックアップファイルの確認
ls -la config_backup_*.tar.gz

# バックアップの安全な保存
mkdir -p /backup/freeradius-privacyidea/config/
mv config_backup_*.tar.gz /backup/freeradius-privacyidea/config/
```

#### 設定ファイルリストア

```bash
# バックアップファイルの展開
tar -xzf config_backup_20250122_143000.tar.gz

# 特定のファイルのみ展開
tar -xzf config_backup_20250122_143000.tar.gz .env
tar -xzf config_backup_20250122_143000.tar.gz privacyidea/certs/enckey

# 展開前の内容確認
tar -tzf config_backup_20250122_143000.tar.gz
```

#### 重要な注意事項

**⚠️ 設定ファイルバックアップの重要性:**
- **暗号化キー（enckey）**: 失うと既存のTOTPトークンが無効になる
- **SSL証明書**: サービスの継続性に必要
- **環境変数（.env）**: データベース接続情報等を含む
- **設定ファイル**: FreeRADIUS、nginx、PrivacyIDEAの動作設定

**⚠️ セキュリティ注意事項:**
```bash
# バックアップファイルの権限設定
chmod 600 config_backup_*.tar.gz

# バックアップの暗号化（推奨）
gpg --symmetric --cipher-algo AES256 config_backup_20250122_143000.tar.gz
rm config_backup_20250122_143000.tar.gz  # 元ファイルを削除
```

### 4. backup_cron.sh - 自動バックアップスクリプト## バックアップ・リストアスクリプト

### バックアップ対象

このガイドでは以下の2種類のバックアップを扱います：

1. **データベースバックアップ** - PostgreSQLデータベース（ユーザー、トークン、認証データ等）
2. **設定ファイルバックアップ** - 環境設定、証明書、設定ファイル

### データベースバックアップスクリプト

### 1. backup_database.sh - 手動バックアップスクリプト
データベースの手動バックアップを作成します。

**使用方法:**
```bash
./scripts/backup_database.sh [backup_type] [backup_name]
```

**バックアップタイプ:**
- `full` - 完全バックアップ（デフォルト）
- `schema` - スキーマのみ
- `data` - データのみ
- `compressed` - 圧縮形式

**例:**
```bash
# 完全バックアップ
./scripts/backup_database.sh

# スキーマのみバックアップ
./scripts/backup_database.sh schema

# カスタム名でバックアップ
./scripts/backup_database.sh full my_backup_name
```

### 2. restore_database.sh - データベースリストアスクリプト
バックアップファイルからデータベースをリストアします。

**使用方法:**
```bash
./scripts/restore_database.sh <backup_file> [options]
```

**オプション:**
- `--clean` - リストア前に既存データベースを削除
- `--create` - データベースが存在しない場合は作成
- `--data-only` - データのみリストア
- `--schema-only` - スキーマのみリストア

**例:**
```bash
# 基本的なリストア
./scripts/restore_database.sh backups/privacyidea_full_20250721_143000.sql

# クリーンリストア（既存データを削除）
./scripts/restore_database.sh backups/privacyidea_full_20250721_143000.sql --clean

# データのみリストア
./scripts/restore_database.sh backups/privacyidea_data_20250721_143000.sql --data-only
```

### 3. db_management.sh - データベース管理ユーティリティ
データベースの状態確認と管理操作を行います。

**使用方法:**
```bash
./scripts/db_management.sh <command>
```

**コマンド:**
- `status` - データベース状態の表示
- `tables` - テーブル一覧と行数表示
- `size` - データベースとテーブルサイズ表示
- `users` - ユーザーと権限表示
- `vacuum` - データベースメンテナンス実行
- `analyze` - 統計情報更新
- `check` - 整合性チェック
- `shell` - 対話型PostgreSQLシェル起動

**例:**
```bash
# データベース状態確認
./scripts/db_management.sh status

# テーブルサイズ確認
./scripts/db_management.sh size

# メンテナンス実行
./scripts/db_management.sh vacuum

# 対話型シェル
./scripts/db_management.sh shell
```

### 4. backup_cron.sh - 自動バックアップスクリプト
cron等での自動実行に適したバックアップスクリプトです。

**使用方法:**
```bash
./scripts/backup_cron.sh [daily|weekly|monthly]
```

**特徴:**
- ログ出力機能
- ディスク容量チェック
- 古いバックアップの自動削除
- エラー通知機能

## 設定と前提条件

### 前提条件
1. Docker ComposeでPostgreSQLコンテナが起動していること
2. `.env`ファイルに以下の環境変数が設定されていること：
   - `DB_USER` - PostgreSQLユーザー名
   - `DB_PASSWORD` - PostgreSQLパスワード
   - `DB_NAME` - データベース名（通常は`privacyidea`）
   - `DB_HOST` - データベースホスト（通常は`localhost`または`PostgreSQL`）

### ディレクトリ構造
```
project_root/
├── scripts/              # バックアップスクリプト
├── backups/              # バックアップファイル保存先（自動作成）
├── logs/                 # ログファイル保存先（自動作成）
└── .env                  # 環境変数設定ファイル
```

## 自動バックアップの設定

### Makefileコマンド
プロジェクトでは、バックアップとリストアのMakefileコマンドも提供しています：

```bash
# データベースバックアップ
make backup              # 手動バックアップ実行

# バックアップ一覧表示
ls -la backups/

# リストア（対話式）
make restore
```

### crontabの設定例
```bash
# crontabを編集
crontab -e

# 毎日午前2時に日次バックアップ
0 2 * * * /path/to/project/scripts/backup_cron.sh daily

# 毎週日曜日午前3時に週次バックアップ
0 3 * * 0 /path/to/project/scripts/backup_cron.sh weekly

# 毎月1日午前4時に月次バックアップ
0 4 1 * * /path/to/project/scripts/backup_cron.sh monthly
```

### バックアップ保持ポリシー
- **日次バックアップ**: 7日間保持
- **週次バックアップ**: 4週間保持
- **月次バックアップ**: 12ヶ月保持

## 災害復旧手順

### 完全復旧シナリオ

1. **新しい環境での環境構築**
   ```bash
   # プロジェクトをクローン
   git clone <repository-url>
   cd FreeRADIUS-privacyIDEA_\(Docker\)
   ```

2. **設定ファイルのリストア**
   ```bash
   # 設定ファイルバックアップのリストア
   tar -xzf config_backup_YYYYMMDD_HHMMSS.tar.gz
   
   # 重要ファイルの確認
   ls -la .env
   ls -la privacyidea/certs/enckey
   ```

3. **サービス起動**
   ```bash
   # 証明書が含まれていない場合のみ実行
   # make init-certs
   
   # 基本サービス起動
   make up
   ```

4. **データベースリストア**
   ```bash
   # 最新のバックアップファイルを確認
   ls -la backups/
   
   # データベースリストア
   ./scripts/restore_database.sh backups/privacyidea_full_YYYYMMDD_HHMMSS.sql --clean
   ```

5. **動作確認**
   ```bash
   # サービス状態確認
   make status
   
   # 認証テスト
   make test-auth
   ```

### 部分復旧シナリオ（データのみ）

```bash
# サービス停止
make stop

# データのみリストア
./scripts/restore_database.sh backups/privacyidea_data_YYYYMMDD_HHMMSS.sql --data-only

# サービス再起動
make up
```

## トラブルシューティング

### よくある問題

1. **"PostgreSQL container is not running"エラー**
   ```bash
   # PostgreSQLコンテナを起動
   docker compose up -d postgres
   
   # コンテナ状態確認
   docker compose ps postgres
   ```

2. **権限エラー**
   ```bash
   # スクリプトに実行権限を付与
   chmod +x scripts/*.sh
   
   # バックアップディレクトリの権限確認
   ls -la backups/
   ```

3. **環境変数エラー**
   ```bash
   # .envファイルの確認
   cat .env | grep -E "DB_USER|DB_PASSWORD"
   
   # 環境変数のテスト
   docker compose exec postgres psql -U $DB_USER -d privacyidea -c "SELECT version();"
   ```

4. **ディスク容量不足**
   ```bash
   # ディスク容量確認
   df -h
   du -sh backups/
   
   # 古いバックアップファイルの削除
   find backups/ -name "*.sql" -mtime +30 -delete
   ```

### ログ確認

```bash
# バックアップログ確認
tail -f logs/backup_cron_$(date +%Y%m).log

# データベースコンテナログ確認
docker compose logs postgres

# PostgreSQLログ確認
docker compose exec postgres tail -f /var/log/postgresql/postgresql-*.log
```

### バックアップファイルの検証

```bash
# バックアップファイルの整合性確認
head -n 10 backups/privacyidea_full_YYYYMMDD_HHMMSS.sql
tail -n 10 backups/privacyidea_full_YYYYMMDD_HHMMSS.sql

# ファイルサイズ確認
ls -lh backups/privacyidea_full_YYYYMMDD_HHMMSS.sql

# SQL構文確認（dry run）
docker compose exec postgres psql -U $DB_USER -d privacyidea --single-transaction --set ON_ERROR_STOP=on --dry-run -f /path/to/backup.sql
```

## セキュリティ注意事項

### バックアップファイルの保護

1. **ファイル権限の設定**
   ```bash
   # バックアップファイルの権限制限
   chmod 600 backups/*.sql
   
   # スクリプトディレクトリの権限制限
   chmod 700 scripts/
   ```

2. **バックアップファイルの暗号化**
   ```bash
   # GPGを使用した暗号化
   gpg --symmetric --cipher-algo AES256 backups/privacyidea_full_YYYYMMDD_HHMMSS.sql
   
   # 暗号化されたファイルの復号化
   gpg --decrypt backups/privacyidea_full_YYYYMMDD_HHMMSS.sql.gpg > restored_backup.sql
   ```

3. **リモートストレージへの安全な転送**
   ```bash
   # SSH/SCPを使用した安全な転送
   scp backups/privacyidea_full_YYYYMMDD_HHMMSS.sql.gpg user@backup-server:/secure/backup/location/
   
   # rsyncを使用した同期
   rsync -avz --delete backups/ user@backup-server:/backup/privacyidea/
   ```

### アクセス制御

```bash
# バックアップ専用ユーザーの作成
sudo useradd -r -s /bin/false backup-user

# バックアップディレクトリの所有者変更
sudo chown -R backup-user:backup-user backups/

# sudoersファイルでバックアップコマンドのみ許可
echo "backup-user ALL=(ALL) NOPASSWD: /path/to/project/scripts/backup_database.sh" | sudo tee -a /etc/sudoers.d/backup-user
```

## 監視とアラート

### ヘルスチェック用スクリプト

```bash
#!/bin/bash
# scripts/backup_health_check.sh

# バックアップの健全性チェック
BACKUP_DIR="backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/privacyidea_daily_*.sql* 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No recent backups found in $BACKUP_DIR"
    exit 1
fi

# 24時間以内のバックアップがあるかチェック
if [ $(find $BACKUP_DIR/ -name "privacyidea_daily_*.sql*" -mtime -1 2>/dev/null | wc -l) -eq 0 ]; then
    echo "WARNING: No backups created in last 24 hours"
    exit 1
fi

# バックアップファイルサイズチェック（1MB未満は異常とみなす）
BACKUP_SIZE=$(stat -c%s "$LATEST_BACKUP" 2>/dev/null || echo 0)
if [ $BACKUP_SIZE -lt 1048576 ]; then
    echo "WARNING: Latest backup file is too small: $BACKUP_SIZE bytes"
    exit 1
fi

echo "Backup health check passed"
echo "Latest backup: $LATEST_BACKUP ($(($BACKUP_SIZE / 1024 / 1024)) MB)"
exit 0
```

### アラート設定

```bash
# メール通知機能付きバックアップスクリプト
#!/bin/bash
# scripts/backup_with_notification.sh

BACKUP_RESULT=$(./scripts/backup_database.sh daily 2>&1)
BACKUP_STATUS=$?

if [ $BACKUP_STATUS -eq 0 ]; then
    echo "Backup completed successfully" | mail -s "Backup Success - PrivacyIDEA" admin@example.com
else
    echo "Backup failed: $BACKUP_RESULT" | mail -s "Backup Failed - PrivacyIDEA" admin@example.com
fi
```

## バックアップ戦略の推奨事項

### 3-2-1バックアップルール

1. **3つのコピー**
   - 本番データ（PostgreSQLデータベース）
   - ローカルバックアップ（`backups/`ディレクトリ）
   - リモートバックアップ（外部ストレージ）

2. **2つの異なるメディア**
   - ローカルディスク
   - クラウドストレージまたは外部ストレージ

3. **1つのオフサイトバックアップ**
   - 地理的に離れた場所でのバックアップ保存

### 定期的なリストアテスト

```bash
#!/bin/bash
# scripts/monthly_restore_test.sh

# 月次リストアテスト
TEST_DATE=$(date +%Y%m%d)
TEST_ENV="test_restore_$TEST_DATE"

echo "Starting monthly restore test: $TEST_DATE"

# テスト環境でのリストア実行
docker compose -f docker-compose.test.yml up -d postgres
sleep 10

# 最新のバックアップをリストア
LATEST_BACKUP=$(ls -t backups/privacyidea_full_*.sql | head -1)
./scripts/restore_database.sh $LATEST_BACKUP --test-env

# 基本的な整合性チェック
TEST_RESULT=$(docker compose -f docker-compose.test.yml exec postgres psql -U pi -d privacyidea -c "SELECT COUNT(*) FROM token;" 2>/dev/null)

if [[ $TEST_RESULT =~ [0-9]+ ]]; then
    echo "Restore test PASSED: Database contains data"
    echo "Restore test passed on $TEST_DATE" | mail -s "Monthly Restore Test Success" admin@example.com
else
    echo "Restore test FAILED: No data found"
    echo "Restore test failed on $TEST_DATE" | mail -s "Monthly Restore Test Failed" admin@example.com
fi

# テスト環境のクリーンアップ
docker compose -f docker-compose.test.yml down -v
```

### バックアップの整合性確認

```bash
#!/bin/bash
# scripts/backup_integrity_check.sh

for backup_file in backups/privacyidea_*.sql; do
    echo "Checking: $backup_file"
    
    # チェックサム生成
    md5sum "$backup_file" > "${backup_file}.md5"
    
    # SQL構文確認
    if head -n 100 "$backup_file" | grep -q "PostgreSQL database dump"; then
        echo "  ✓ Valid PostgreSQL dump format"
    else
        echo "  ✗ Invalid dump format"
    fi
    
    # ファイルサイズ確認
    size=$(stat -c%s "$backup_file")
    if [ $size -gt 1048576 ]; then
        echo "  ✓ File size OK: $(($size / 1024 / 1024)) MB"
    else
        echo "  ✗ File size too small: $size bytes"
    fi
done
```

## 高可用性環境でのバックアップ

### マスター・スレーブ構成でのバックアップ

```bash
# scripts/ha_backup.sh
#!/bin/bash

# スレーブサーバーからのバックアップ（本番への影響最小化）
SLAVE_HOST="slave-db-server"
pg_dump -h $SLAVE_HOST -U pi privacyidea > backups/privacyidea_slave_$(date +%Y%m%d_%H%M%S).sql
```

### レプリケーション遅延の考慮

```bash
# レプリケーション遅延チェック
LAG=$(docker compose exec postgres psql -U pi -d privacyidea -t -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()));" 2>/dev/null | tr -d ' ')

if [ "${LAG%%.*}" -gt 300 ]; then
    echo "WARNING: Replication lag is ${LAG} seconds"
fi
```

このバックアップガイドを参考に、環境に応じたバックアップ戦略を実装してください。定期的なバックアップの実行とリストアテストにより、データの安全性を確保できます。
