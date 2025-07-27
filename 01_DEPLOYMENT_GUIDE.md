# FreeRADIUS-privacyIDEA (Docker) デプロイメントガイド

## 概要

このプロジェクトは、Docker ComposでFreeRADIUS、privacyIDEA、PostgreSQL、nginxを統合したRADIUS認証システムです。このガイドでは、初期デプロイメントから動作確認までの手順を説明します。

## システム要件

### ハードウェア要件
- **CPU**: 2コア以上推奨
- **メモリ**: 最低4GB、推奨8GB以上
- **ディスク**: 20GB以上の空き容量
- **ネットワーク**: インターネット接続（Dockerイメージダウンロード用）

### ソフトウェア要件
- **OS**: Linux (Ubuntu 20.04+, CentOS 8+, Debian 11+)
- **Docker**: 20.10以降
- **Docker Compose**: 2.0以降
- **必要な権限**: sudo または dockerグループメンバー

## 初期デプロイメント

### 1. リポジトリの取得

```bash
# リポジトリをクローン
git clone <repository-url>
cd FreeRADIUS-privacyIDEA_\(Docker\)

# ディレクトリ構造の確認
ls -la
```

### 2. 環境設定ファイルの準備

```bash
# .env.example から .env をコピー
cp .env.example .env

# .envファイルを編集
nano .env  # または vi .env
```

**重要**: 以下のパスワードは必ず変更してください：

```bash
# データベース設定
DB_USER=pi
DB_PASSWORD=your_secure_password_here          # 変更必須

# PrivacyIDEA設定  
PI_ADMIN_PASS=your_secure_admin_password       # 変更必須
PI_PASSWORD=your_secure_pi_password            # 変更必須
PI_PEPPER=your_secure_pepper_32_chars_minimum  # 変更必須（32文字以上）

# RADIUS設定
RADIUS_SECRET=your_secure_radius_secret        # 変更必須
```

### 3. 証明書と暗号化キーの生成

```bash
# 証明書と暗号化キーを生成
make init-certs

# 生成されたファイルの確認
ls -la nginx/certs/
ls -la freeradius/certs/
ls -la privacyidea/certs/
```

**重要**: `privacyidea/certs/enckey`ファイルは一度生成したら絶対に削除・変更しないでください。

### 4. サービスの起動

```bash
# すべてのサービスを起動
make up

# 起動ログを確認
make logs
```

### 5. サービス状態の確認

```bash
# コンテナの状態を確認
make status

# または詳細確認
docker compose ps
```

**正常な状態の例**:
```
NAME          COMMAND                  SERVICE      STATUS          PORTS
FreeRADIUS    "/docker-entrypoint.…"   freeradius   Up (healthy)    0.0.0.0:1812-1813->1812-1813/udp
PrivacyIDEA   "/docker-entrypoint.…"   privacyidea  Up (healthy)    8080/tcp
PostgreSQL    "docker-entrypoint.s…"   postgres     Up (healthy)    5432/tcp
nginx         "/docker-entrypoint.…"   nginx        Up (healthy)    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

## 動作確認

### Web UI動作確認

1. **ブラウザでアクセス**
   ```
   http://localhost
   または
   https://localhost (自己署名証明書のため警告が表示される場合があります)
   ```

2. **管理者ログイン**
   - ユーザー名: `admin`
   - パスワード: `.env`ファイルで設定した`PI_ADMIN_PASS`

3. **初回ログイン後の設定**
   - 管理者パスワードの変更（推奨）
   - システム設定の確認

### RADIUS認証の動作確認

```bash
# 基本認証テスト（第1段階のみ）
make test-auth

# 期待される結果の例:
# Sent Access-Request Id xxx from 0.0.0.0:xxxxx to 127.0.0.1:1812
# Received Access-Challenge Id xxx from 127.0.0.1:1812
```

### データベース接続確認

```bash
# PostgreSQLへの接続テスト
docker compose exec postgres psql -U pi -d privacyidea -c "SELECT version();"

# 期待される結果: PostgreSQLのバージョン情報が表示される
```

### ネットワーク接続確認

```bash
# サービス間の通信確認
docker compose exec privacyidea ping -c 3 postgres
docker compose exec freeradius ping -c 3 privacyidea
```

## 初期設定

### privacyIDEA初期設定

1. **レルムの設定**
   - Config → Realms で新しいレルムを作成
   - デフォルトレルムの設定

2. **認証方式の設定**
   - Config → Policies で認証ポリシーを設定
   - RADIUS認証の有効化

3. **テストユーザーの作成**
   - Users → User Details でテストユーザーを作成
   - パスワードの設定

### FreeRADIUS初期設定確認

```bash
# clients.confの確認
cat freeradius/conf/clients.conf

# 設定が正しく読み込まれているか確認
docker compose exec freeradius radtest testuser testpass localhost 1812 testing123
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. コンテナが起動しない

```bash
# エラーログを確認
make logs

# 個別サービスのログ確認
docker compose logs postgres
docker compose logs privacyidea
docker compose logs freeradius
docker compose logs nginx
```

**解決方法**:
- `.env`ファイルの設定を確認
- ポート競合の確認（80, 443, 1812, 1813）
- ディスク容量の確認

#### 2. Web UIにアクセスできない

```bash
# nginxの状態確認
docker compose logs nginx

# ポート使用状況確認
netstat -tulpn | grep -E ':(80|443)'
```

**解決方法**:
- nginxコンテナの再起動
- ファイアウォール設定の確認
- SSL証明書の再生成

#### 3. データベース接続エラー

```bash
# PostgreSQLの状態確認
docker compose logs postgres

# 直接接続テスト
docker compose exec postgres pg_isready -U pi
```

**解決方法**:
- `.env`ファイルのDB設定確認
- postgresコンテナの再起動
- データディレクトリの権限確認

#### 4. RADIUS認証が失敗する

```bash
# FreeRADIUSデバッグモードで確認
make debug-up
make freeradius-logs
```

**解決方法**:
- clients.confの設定確認
- privacyIDEAとの通信確認
- 認証ポリシーの設定確認

### デバッグモードの使用

問題の詳細な診断には、デバッグモードを使用します：

```bash
# デバッグモードで起動
make debug-up

# デバッグツールコンテナに接続
make debug-shell

# ネットワーク診断
ping privacyidea
nslookup privacyidea

# 通常モードに戻す
make debug-down
```

## セキュリティ考慮事項

### 初期デプロイ時の必須設定

1. **パスワードの変更**
   - すべてのデフォルトパスワードを変更
   - 強力なパスワードの使用

2. **ファイル権限の設定**
   ```bash
   chmod 600 .env
   chmod 600 privacyidea/certs/enckey
   ```

3. **ネットワークアクセス制限**
   - 必要なポートのみ公開
   - ファイアウォール設定

### 本番環境への準備

- **SSL証明書**: Let's Encryptや内部CAからの正式な証明書を使用
- **バックアップ設定**: 自動バックアップの設定
- **監視設定**: ヘルスチェックとアラート設定
- **ログ管理**: ログローテーションとアーカイブ設定
- **アクセス制限**: nginxでのIP制限、時間帯制限等の設定

## 次のステップ

デプロイメントが完了したら、以下のドキュメントを参照してください：

- **[02_CONFIGURATION.md](02_CONFIGURATION.md)** - 詳細な設定方法（nginx、RADIUS、privacyIDEA等）
- **[03_OPERATIONS_GUIDE.md](03_OPERATIONS_GUIDE.md)** - 日常運用・メンテナンス手順
- **[scripts/README.md](scripts/README.md)** - 運用スクリプトの使用方法

### 推奨する次の設定作業

1. **セキュリティ設定** ([02_CONFIGURATION.md](02_CONFIGURATION.md)参照)
   - nginxアクセス制限（IP、地理的、時間帯制限）
   - レート制限とDDoS対策
   - SSL/TLSセキュリティ強化

2. **認証設定の詳細調整** ([02_CONFIGURATION.md](02_CONFIGURATION.md)参照)
   - privacyIDEA詳細設定
   - FreeRADIUS認証ポリシー
   - TOTP設定のカスタマイズ

3. **運用準備** ([03_OPERATIONS_GUIDE.md](03_OPERATIONS_GUIDE.md)参照)
   - 自動バックアップ設定
   - 監視とアラート設定
   - ログ管理とローテーション

## サポート

問題が発生した場合：
1. ログを確認（`make logs`）
2. このドキュメントのトラブルシューティングを確認
3. GitHubのIssuesで報告
