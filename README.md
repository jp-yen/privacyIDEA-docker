# FreeRADIUS + PrivacyIDEA Docker Environment

## 概要

このプロジェクトは、Docker Composeを使用してFreeRADIUS、privacyIDEA、PostgreSQL、nginxを統合したRADIUS認証システムです。

### アーキテクチャ

```
[RADIUS Client] → [FreeRADIUS:1812] → [PrivacyIDEA:8080] → [LDAP/AD Server]
                                    ↓
                                [PostgreSQL Database]
                                    ↑
                                [nginx:80/443]
```

### 主要な機能

- **2要素認証**: パスワード + TOTP（Time-based One-Time Password）
- **LDAP/AD連携**: 既存のActive Directoryとの統合
- **証明書自動生成**: 開発・テスト環境用SSL証明書
- **暗号化キー永続化**: コンテナ再起動後もデータ保持
- **デバッグツール**: 統合された診断・テスト機能

## クイックスタート

### 前提条件
- Docker および Docker Compose
- 必要な権限（sudo または dockerグループメンバー）

### 初期セットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd FreeRADIUS-privacyIDEA_\(Docker\)

# 環境設定ファイルを準備
cp .env.example .env
# .envファイルを編集してパスワード等を設定

# 証明書と暗号化キーを生成
make init-certs

# サービス起動
make up

# 状態確認
make status
```

### アクセスポイント

- **PrivacyIDEA管理画面**: http://localhost
- **RADIUS認証**: ポート1812/UDP
- **デフォルト管理者**: admin/admin（初回ログイン後に変更）

## 基本的な使用方法

### 認証テスト

```bash
# 基本認証テスト（パスワードのみ）
make test-auth

# デバッグモードでの詳細テスト
make debug-up
make debug-shell
/debug/scripts/test_radius_totp.pl user01 pass01 123456 freeradius
```

### 日常運用コマンド

```bash
# サービス管理
make up                  # サービス起動
make stop                # サービス停止
make restart             # サービス再起動
make status              # 状態確認
make logs                # ログ表示

# デバッグ
make debug-up            # デバッグモードで起動
make debug-down          # デバッグモード停止
make freeradius-logs     # FreeRADIUSログ表示

# メンテナンス
make clean-data          # データクリア
make help                # 利用可能コマンド一覧
```

## ドキュメント構成

### 📋 [README.md](README.md) (このファイル)
**対象**: 初めてプロジェクトを使用する開発者・管理者  
**内容**: プロジェクト概要、アーキテクチャ、クイックスタート手順

### 🚀 [01_DEPLOYMENT_GUIDE.md](01_DEPLOYMENT_GUIDE.md)
**対象**: 本番環境へのデプロイを行う管理者  
**内容**: 詳細なデプロイ手順、運用管理、トラブルシューティング、セキュリティ対策

### ⚙️ [02_CONFIGURATION.md](02_CONFIGURATION.md)
**対象**: 設定をカスタマイズしたい管理者・開発者  
**内容**: 全設定ファイルの詳細説明、パラメータ解説、設定例

### 🛠️ [03_OPERATIONS_GUIDE.md](03_OPERATIONS_GUIDE.md)
**対象**: 日常運用・メンテナンスを行う管理者  
**内容**: 詳細な運用手順、監視、トラブルシューティング、システムメンテナンス

### 💾 [04_BACKUP_GUIDE.md](04_BACKUP_GUIDE.md)
**対象**: バックアップ・復旧を担当する管理者  
**内容**: データベースバックアップ、リストア手順、災害復旧、自動化設定

### 🛠️ [05_SCRIPTS_GUIDE.md](05_SCRIPTS_GUIDE.md)
**対象**: 日常運用スクリプトを使用する管理者  
**内容**: Makefileコマンド、運用スクリプトの使用方法、テスト手順

## セキュリティ注意事項

⚠️ **重要**: 
- `.env`ファイルのパスワードを必ず変更してください
- `privacyidea/certs/enckey`は削除・変更しないでください
- 本番環境では適切な証明書を使用してください

## サポート

問題が発生した場合：
1. `make logs`でログを確認
2. [01_DEPLOYMENT_GUIDE.md](01_DEPLOYMENT_GUIDE.md)のトラブルシューティングを参照
3. [03_OPERATIONS_GUIDE.md](03_OPERATIONS_GUIDE.md)の詳細なトラブルシューティング手順を参照
