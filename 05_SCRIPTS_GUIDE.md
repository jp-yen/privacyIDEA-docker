# スクリプトとMakefileガイド

## 概要

このディレクトリには、FreeRADIUS-privacyIDEA Docker環境の運用・管理・テスト用スクリプトが含まれています。

**📋 バックアップ・リストアの詳細については、[04_BACKUP_GUIDE.md](04_BACKUP_GUIDE.md)を参照してください。**

## Makefileコマンド

プロジェクトルートの`Makefile`は運用を簡素化するための統合コマンドを提供します。

### 基本コマンド

```bash
# ヘルプ表示
make help

# 初期セットアップ
make init-certs          # 証明書と暗号化キーを生成
make up                  # サービス起動

# 日常運用
make stop                # サービス停止
make restart             # サービス再起動
make status              # コンテナ状態確認
make logs                # ログ表示
```

### デバッグコマンド

```bash
make debug-up            # デバッグモードで起動
make debug-down          # デバッグモード停止
make debug-shell         # デバッグツールシェルに接続
make debug-stop          # デバッグモード完全停止
make freeradius-logs     # FreeRADIUSログ表示
make freeradius-logs-recent # FreeRADIUSの最新ログ
make test-auth           # RADIUS認証テスト
```

### メンテナンスコマンド

```bash
make clean-data          # データと証明書をクリア
make clean-images        # プロジェクトイメージを削除
make clean-all           # すべてのリソースを削除
make update-certs        # 証明書のみ更新（enckeyは保持）
```

## 含まれるスクリプト

### 認証テストスクリプト

#### test_radius_totp.pl - TOTP完全認証テストスクリプト
2要素認証（TOTP）の完全テストを実行するPerlスクリプトです。

**使用方法:**
```bash
# 基本的な使用方法（本番モード）
perl scripts/test_radius_totp.pl <ユーザー名> <パスワード> <TOTPコード> <サーバーIP> [ポート]

# 本番モードでの直接実行
cd scripts
perl test_radius_totp.pl user01 pass01 705505 127.0.0.1

# Makefileのtest-authターゲット使用（推奨）
make test-auth
```

**本番モードでの実行例:**
```bash
# 現在の本番モード（FreeRADIUS非応答）
$ cd scripts
$ perl test_radius_totp.pl user01 pass01 705505 127.0.0.1
(0) -: Expected Access-Accept got Access-Reject
チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。
$ echo $?
2

# パスワード間違いの場合（本番モードでは同じ結果）
$ perl test_radius_totp.pl user01 wrongpass 705505 127.0.0.1
(0) -: Expected Access-Accept got Access-Reject
チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。
$ echo $?
2

# 存在しないユーザーの場合（本番モードでは同じ結果）
$ perl test_radius_totp.pl wronguser pass01 705505 127.0.0.1
(0) -: Expected Access-Accept got Access-Reject
チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。
$ echo $?
2
```

**デバッグモードでの詳細な実行例:**
```bash
# 現在の状況（PrivacyIDEA接続エラー）
$ make debug-shell
$ /debug/scripts/test_radius_totp.pl user01 pass01 705505 127.0.0.1
チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。

# FreeRADIUSログで確認できる実際のエラー内容：
# rlm_perl: privacyIDEA request failed: 404 NOT FOUND
# rlm_perl: Can not parse response from privacyIDEA
# Reply-Message = "privacyIDEA request failed: 404 NOT FOUND"

# 正常認証の場合（PrivacyIDEAが正しく設定され、TOTPが有効な場合の理論例）
$ /debug/scripts/test_radius_totp.pl user01 pass01 705505 127.0.0.1
チャレンジ受信: State = 0x3fd2c2e8ed4b7f5c8a9e9f1e8a7b6c5d
認証結果:
Received Access-Accept Id 42 from 127.0.0.1:1812 to 0.0.0.0:0
	Reply-Message = "matching 1 tokens"
	Class = 0x707269766163796964656141757468

# パスワード間違いの場合（現在は404エラーで同じ結果）
$ /debug/scripts/test_radius_totp.pl user01 wrongpass 705505 127.0.0.1
チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。

# clients.confの共有秘密が間違っている場合
$ # (clients.confを手動で変更した場合)
$ /debug/scripts/test_radius_totp.pl user01 pass01 705505 127.0.0.1
(0) -: no reply from server for ID 44 socket 3
```

**注意事項:**
- **本番モードの制限**: FreeRADIUSがRADIUSリクエストに応答しないため、すべてのテストが同じエラーになります
- **現在の環境状況**: PrivacyIDEAへの接続で404エラーが発生し、認証テストが正常に動作していません
- **初期設定の必要性**: PrivacyIDEAの管理画面でのユーザー作成とTOTPトークン設定、API設定の確認が必要です
- **設定確認方法**: `make freeradius-logs-recent`でFreeRADIUSログを確認し、具体的なエラー内容を把握してください
- **トラブルシューティング**: 404エラーはPrivacyIDEAのURL設定やAPI有効化の問題を示唆しています
- **推奨アプローチ**: まずPrivacyIDEA管理画面（https://localhost）で初期設定を完了してください
- **セキュリティ**: 本番環境では実際の認証情報を使ったテストは避け、デバッグ環境で行ってください

**デバッグモードでの詳細テスト:**
```bash
# より詳細なテストが必要な場合
make debug-up
make debug-shell
/debug/scripts/test_radius_totp.pl user01 pass01 705505 127.0.0.1
```

**特徴:**
- clients.confから共有秘密を自動読み込み
- Challenge-Response方式でTOTP認証を実行
- 2段階認証プロセス（パスワード → TOTPコード）
- 詳細なRADIUS通信ログを表示

**認証成功時の動作解説:**
1. **第1段階**: パスワード認証でチャレンジ（State）を受信
2. **第2段階**: State値と共にTOTPコードを送信
3. **成功応答**: `Reply-Message = "matching 1 tokens"`でトークン照合成功を確認
4. **Class属性**: privacyIDEA認証を示す識別子が含まれる

### バックアップ・データベース管理スクリプト

詳細なバックアップ・リストア手順については、**[04_BACKUP_GUIDE.md](04_BACKUP_GUIDE.md)**を参照してください。

### 証明書生成スクリプト

#### generate_cert.sh - SSL証明書生成スクリプト
開発・テスト環境用のSSL証明書を生成します。

**使用方法:**
```bash
./scripts/generate_cert.sh
```

### ネットワーク・システムテストスクリプト

#### test_network.sh - ネットワーク接続テスト
サービス間のネットワーク接続をテストします。

**使用方法:**
```bash
# デバッグ環境で実行
make debug-up
make debug-shell
/debug/scripts/test_network.sh
```

#### test_postgresql.sh - PostgreSQL接続テスト
データベース接続をテストします。

#### test_privacyidea.sh - PrivacyIDEA API テスト
PrivacyIDEA Web API の動作をテストします。

#### test_radius.sh - RADIUS認証テスト
基本的なRADIUS認証をテストします。

### ログ・デバッグスクリプト

#### capture_radius.sh - RADIUS通信キャプチャ
RADIUS認証の詳細なネットワーク通信をキャプチャします。

#### run_all_tests.sh - 包括的システムテスト
全てのテストスクリプトを順次実行します。

## 使用方法

### 基本的な運用フロー

1. **初期セットアップ**
   ```bash
   make init-certs
   make up
   make status
   ```

2. **日常運用**
   ```bash
   make status              # 状態確認
   make logs                # ログ確認
   make test-auth           # 認証テスト
   ```

3. **デバッグが必要な場合**
   ```bash
   make debug-up            # デバッグモード起動
   make debug-shell         # デバッグコンテナ接続
   /debug/scripts/run_all_tests.sh  # 包括テスト実行
   make debug-down          # 通常モードに戻る
   ```

4. **メンテナンス**
   ```bash
   make update-certs        # 証明書更新
   make clean-data          # データクリア（要注意）
   ```

### トラブルシューティング

#### 認証が失敗する場合
```bash
# デバッグモードで詳細ログを確認
make debug-up
make freeradius-logs

# ネットワーク接続テスト
make debug-shell
/debug/scripts/test_network.sh
/debug/scripts/test_radius.sh
```

#### サービスが起動しない場合
```bash
# コンテナ状態確認
make status
docker compose ps

# ログ確認
make logs
docker compose logs <service_name>
```

#### 設定変更後の確認
```bash
# 設定の構文チェック
docker compose config --quiet

# サービス再起動
make restart

# 動作確認
make test-auth
```

## セキュリティ注意事項

1. **スクリプトの実行権限**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **ログファイルの管理**
   - デバッグログには機密情報が含まれる可能性があります
   - 本番環境では適切なログローテーションを設定してください

3. **テスト環境での使用**
   - 認証テストスクリプトは開発・テスト環境でのみ使用してください
   - 本番環境では慎重に実行してください

## 高度な使用例

### カスタムテストシナリオ

```bash
# 特定ユーザーでのTOTP認証テスト
make debug-shell
/debug/scripts/test_radius_totp.pl testuser password123 123456 freeradius

# ネットワーク診断
/debug/scripts/capture_radius.sh &  # バックグラウンドでキャプチャ開始
/debug/scripts/test_radius.sh        # テスト実行
```

### パフォーマンステスト

```bash
# 複数同時認証のテスト
for i in {1..10}; do
    /debug/scripts/test_radius.sh &
done
wait
```

### 継続的監視

```bash
# ログ監視スクリプト例
#!/bin/bash
while true; do
    make test-auth
    if [ $? -ne 0 ]; then
        echo "$(date): Authentication test failed" | tee -a monitoring.log
    fi
    sleep 300  # 5分間隔
done
```

このガイドを参考に、プロジェクトの運用・管理・テストを効率的に行ってください。
