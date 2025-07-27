#!/bin/bash

# PrivacyIDEA PostgreSQLデータベース バックアップスクリプト
#
# 使用方法:
#   ./backup_database.sh [-t|--type バックアップタイプ] [-n|--name ファイル名] [-h|--help]
#
# オプション:
#   -t, --type   バックアップの種類 (full|schema|data|compressed) (デフォルト: full)
#   -n, --name   保存するファイル名（拡張子なし） (任意)
#   -h, --help   このヘルプメッセージを表示
#
# 使用例:
#   ./backup_database.sh                          # デフォルト名でフルバックアップを実行
#   ./backup_database.sh -t schema                # スキーマのみバックアップを実行
#   ./backup_database.sh -t compressed -n mybackup # ファイル名を指定して圧縮バックアップを実行

set -e

# ■ 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +"%Y%m%d_%H%M%S")

# ■ コマンドライン引数の解析
BACKUP_TYPE="full"
BACKUP_NAME=""

show_help() {
    cat << EOF
PrivacyIDEA データベース バックアップスクリプト

使用方法: $0 [オプション]

オプション:
  -t, --type TYPE    バックアップの種類を指定します (full|schema|data|compressed) (デフォルト: full)
  -n, --name NAME    保存するファイル名を指定します（拡張子なし、任意）
  -h, --help         このヘルプメッセージを表示します

バックアップの種類:
  full        データベース全体（スキーマとデータ）のバックアップ (デフォルト)
  schema      スキーマ（テーブル構造、インデックスなど）のみのバックアップ
  data        データのみのバックアップ
  compressed  圧縮形式のバックアップ（大規模データベースに推奨）

使用例:
  $0                                    # デフォルト設定でフルバックアップを実行
  $0 -t schema                          # スキーマのみバックアップを実行
  $0 -t compressed -n mybackup          # ファイル名を指定して圧縮バックアップを実行

注意事項:
  - バックアップは '$PROJECT_DIR/backups' に保存されます。
  - 古いバックアップは自動的に削除されます（最新10件を保持）。
  - 実行前にPostgreSQLコンテナが起動している必要があります。

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -n|--name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "エラー: 不明なオプション '$1'"
            echo "使用方法については --help を参照してください。"
            exit 1
            ;;
    esac
done

# ファイル名が指定されていない場合は、デフォルト名を生成します
if [ -z "$BACKUP_NAME" ]; then
    BACKUP_NAME="privacyidea_${BACKUP_TYPE}_${DATE}"
fi

# .envファイルからデータベース設定を読み込みます
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo "エラー: .envファイルが $PROJECT_DIR に見つかりません。"
    echo "データベース設定が記載された.envファイルを作成してください。"
    exit 1
fi

# 必要な環境変数が設定されているか検証します
if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "エラー: .envファイルでDB_USERとDB_PASSWORDを設定する必要があります。"
    exit 1
fi

# バックアップディレクトリが存在しない場合は作成します
mkdir -p "$BACKUP_DIR"

# PostgreSQLコンテナが実行中か確認する関数
check_postgres_container() {
    if ! docker ps --format "{{.Names}}" | grep -q "^PostgreSQL$"; then
        echo "エラー: PostgreSQLコンテナが起動していません。"
        echo "次のコマンドでデータベースを起動してください: make up"
        exit 1
    fi
}

# フルデータベースバックアップを作成する関数
backup_full() {
    local filename="$BACKUP_DIR/${BACKUP_NAME}.sql"
    echo "フルデータベースバックアップを作成中..."
    echo "対象ファイル: $filename"
    
    docker exec PostgreSQL pg_dump \
        -U "$DB_USER" \
        -d privacyidea \
        --verbose \
        --no-password > "$filename"
    
    echo "フルバックアップが完了しました: $filename"
    echo "ファイルサイズ: $(du -h "$filename" | cut -f1)"
}

# スキーマのみのバックアップを作成する関数
backup_schema() {
    local filename="$BACKUP_DIR/${BACKUP_NAME}_schema.sql"
    echo "スキーマのみのバックアップを作成中..."
    echo "対象ファイル: $filename"
    
    docker exec PostgreSQL pg_dump \
        -U "$DB_USER" \
        -d privacyidea \
        --schema-only \
        --verbose \
        --no-password > "$filename"
    
    echo "スキーマバックアップが完了しました: $filename"
    echo "ファイルサイズ: $(du -h "$filename" | cut -f1)"
}

# データのみのバックアップを作成する関数
backup_data() {
    local filename="$BACKUP_DIR/${BACKUP_NAME}_data.sql"
    echo "データのみのバックアップを作成中..."
    echo "対象ファイル: $filename"
    
    docker exec PostgreSQL pg_dump \
        -U "$DB_USER" \
        -d privacyidea \
        --data-only \
        --verbose \
        --no-password > "$filename"
    
    echo "データバックアップが完了しました: $filename"
    echo "ファイルサイズ: $(du -h "$filename" | cut -f1)"
}

# 圧縮形式のバックアップを作成する関数
backup_compressed() {
    local filename="$BACKUP_DIR/${BACKUP_NAME}.backup"
    echo "圧縮形式のバックアップを作成中..."
    echo "対象ファイル: $filename"
    
    docker exec PostgreSQL pg_dump \
        -U "$DB_USER" \
        -d privacyidea \
        --format=custom \
        --verbose \
        --no-password > "$filename"
    
    echo "圧縮バックアップが完了しました: $filename"
    echo "ファイルサイズ: $(du -h "$filename" | cut -f1)"
}

# ■ メイン処理
echo "=================================================="
echo "PrivacyIDEA データベースバックアップスクリプト"
echo "=================================================="
echo "バックアップタイプ: $BACKUP_TYPE"
echo "保存ファイル名:     $BACKUP_NAME"
echo "保存先ディレクトリ: $BACKUP_DIR"
echo "日時:             $(date)"
echo ""

# PostgreSQLコンテナの実行状態を確認
check_postgres_container

# pg_dump実行のため、パスワードを環境変数に設定
export PGPASSWORD="$DB_PASSWORD"

# バックアップの種類に応じて処理を実行
case "$BACKUP_TYPE" in
    "full")
        backup_full
        ;;
    "schema")
        backup_schema
        ;;
    "data")
        backup_data
        ;;
    "compressed")
        backup_compressed
        ;;
    *)
        echo "エラー: 無効なバックアップタイプが指定されました: '$BACKUP_TYPE'"
        echo "有効なタイプ: full, schema, data, compressed"
        exit 1
        ;;
esac

# 古いバックアップを削除（最新10件を保持）
echo ""
echo "古いバックアップを削除しています..."
cd "$BACKUP_DIR"
ls -t privacyidea_*.{sql,backup} 2>/dev/null | tail -n +11 | xargs -r rm -f
echo "クリーンアップが完了しました。"

echo ""
echo "バックアップ処理が正常に完了しました。"
echo "保存先: $BACKUP_DIR"
echo "現在のバックアップ一覧:"
ls -la "$BACKUP_DIR" | grep -E "\.(sql|backup)$" | tail -5

# セキュリティのため、パスワードの環境変数を削除
unset PGPASSWORD
