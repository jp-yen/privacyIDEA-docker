#!/bin/bash

# PrivacyIDEA PostgreSQLデータベース リストアスクリプト
#
# 使用方法:
#   ./restore_database.sh [-f|--file ファイル名] [オプション]
#
# オプション:
#   -f, --file     バックアップファイルを指定します（必須）
#   --clean        復元前に既存データベースを削除します
#   --create       データベースが存在しない場合は作成します
#   --data-only    データのみ復元します（スキーマは除く）
#   --schema-only  スキーマのみ復元します（データは除く）
#   -h, --help     このヘルプメッセージを表示
#
# 使用例:
#   ./restore_database.sh -f backup.sql              # 基本的な復元
#   ./restore_database.sh -f backup.sql --clean      # 既存データを削除して復元
#   ./restore_database.sh -f backup.backup --create  # 圧縮形式で復元

set -e

# ■ 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"

# ■ コマンドライン引数の解析
BACKUP_FILE=""
CLEAN_DB=false
CREATE_DB=false
DATA_ONLY=false
SCHEMA_ONLY=false

show_help() {
    cat << EOF
PrivacyIDEA データベース リストアスクリプト

使用方法: $0 [オプション]

オプション:
  -f, --file FILE    復元するバックアップファイルを指定します（必須）
  --clean            復元前に既存データベースを削除します
  --create           データベースが存在しない場合は作成します
  --data-only        データのみ復元します（スキーマは除く）
  --schema-only      スキーマのみ復元します（データは除く）
  -h, --help         このヘルプメッセージを表示します

使用例:
  $0 -f backup.sql                      # 基本的な復元
  $0 -f backup.sql --clean              # 既存データを削除して復元
  $0 -f backup.backup --create          # 圧縮形式で復元
  $0 -f backup.sql --data-only          # データのみ復元
  $0 -f schema.sql --schema-only        # スキーマのみ復元

利用可能なバックアップファイル:
EOF
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR" | grep -E "\.(sql|backup)$" | head -5 || echo "  バックアップファイルが見つかりません"
    else
        echo "  バックアップディレクトリが見つかりません: $BACKUP_DIR"
    fi
    cat << EOF

注意事項:
  - 復元前に必ずデータのバックアップを取ってください。
  - 復元処理は既存データを上書きする可能性があります。
  - 実行前にPostgreSQLコンテナが起動している必要があります。

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        --clean)
            CLEAN_DB=true
            shift
            ;;
        --create)
            CREATE_DB=true
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --schema-only)
            SCHEMA_ONLY=true
            shift
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

# バックアップファイルが指定されているか検証
if [ -z "$BACKUP_FILE" ]; then
    echo "エラー: バックアップファイルの指定が必要です。"
    echo "使用方法については --help を参照してください。"
    exit 1
fi

# バックアップファイルが存在するか確認
if [ ! -f "$BACKUP_FILE" ]; then
    # バックアップディレクトリからの相対パスを試行
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        echo "エラー: バックアップファイルが見つかりません: $BACKUP_FILE"
        echo "フルパスを指定するか、ファイルを次の場所に配置してください: $BACKUP_DIR"
        exit 1
    fi
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

# PostgreSQLコンテナが実行中か確認する関数
check_postgres_container() {
    if ! docker ps --format "{{.Names}}" | grep -q "^PostgreSQL$"; then
        echo "エラー: PostgreSQLコンテナが起動していません。"
        echo "次のコマンドでデータベースを起動してください: docker compose up -d postgres"
        exit 1
    fi
}

# PostgreSQLの準備完了を待つ関数
wait_for_postgres() {
    echo "PostgreSQLの準備完了を待機中..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec PostgreSQL pg_isready -U "$DB_USER" -d postgres >/dev/null 2>&1; then
            echo "PostgreSQLの準備が完了しました。"
            return 0
        fi
        echo "試行 $attempt/$max_attempts: PostgreSQLが準備中です。待機中..."
        sleep 2
        ((attempt++))
    done
    
    echo "エラー: PostgreSQLが $max_attempts 回の試行後も準備完了しませんでした。"
    exit 1
}

# データベースを削除する関数
drop_database() {
    echo "既存データベース 'privacyidea' を削除中..."
    
    # セッションを切断してからデータベースを削除
    docker exec PostgreSQL psql -U "$DB_USER" -d postgres --no-password -c "
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE datname = 'privacyidea' AND pid != pg_backend_pid();
    " 2>/dev/null || true
    
    # データベースを削除
    docker exec PostgreSQL psql -U "$DB_USER" -d postgres --no-password -c "DROP DATABASE IF EXISTS privacyidea;" 2>/dev/null || true
    
    echo "データベースが削除されました。"
}

# データベースを作成する関数
create_database() {
    echo "データベース 'privacyidea' を作成中..."
    docker exec PostgreSQL psql -U "$DB_USER" -d postgres --no-password -c "CREATE DATABASE privacyidea OWNER $DB_USER;" 2>/dev/null
    echo "データベースが作成されました。"
}

# SQLファイルから復元する関数
restore_sql() {
    local file="$1"
    local options=""
    
    if [ "$DATA_ONLY" = true ]; then
        options="--data-only"
    elif [ "$SCHEMA_ONLY" = true ]; then
        options="--schema-only"
    fi
    
    echo "SQLファイルから復元中: $(basename "$file")"
    echo "オプション: $options"
    
    # SQLファイルを直接psqlで実行
    docker exec -i PostgreSQL psql \
        -U "$DB_USER" \
        -d privacyidea \
        --no-password \
        --echo-errors < "$file"
    
    echo "SQL復元が完了しました。"
}

# 圧縮形式のバックアップから復元する関数
restore_custom() {
    local file="$1"
    local options=""
    
    if [ "$DATA_ONLY" = true ]; then
        options="--data-only"
    elif [ "$SCHEMA_ONLY" = true ]; then
        options="--schema-only"
    fi
    
    echo "圧縮形式のバックアップから復元中: $(basename "$file")"
    echo "オプション: $options"
    
    # 圧縮バックアップを直接pg_restoreで復元
    docker exec -i PostgreSQL pg_restore \
        -U "$DB_USER" \
        -d privacyidea \
        $options \
        --verbose \
        --no-password < "$file"
    
    echo "圧縮形式の復元が完了しました。"
}

# データベース情報を取得する関数
get_database_info() {
    echo "復元後のデータベース情報:"
    docker exec PostgreSQL psql -U "$DB_USER" -d privacyidea --no-password -c "
        SELECT 
            schemaname,
            tablename,
            tableowner
        FROM pg_tables 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    " 2>/dev/null || echo "テーブル情報を取得できませんでした。"
}

# ■ メイン処理
echo "=================================================="
echo "PrivacyIDEA データベースリストアスクリプト"
echo "=================================================="
echo "バックアップファイル: $BACKUP_FILE"
echo "ファイルサイズ:       $(du -h "$BACKUP_FILE" | cut -f1)"
echo "データベース削除:     $CLEAN_DB"
echo "データベース作成:     $CREATE_DB"
echo "データのみ復元:       $DATA_ONLY"
echo "スキーマのみ復元:     $SCHEMA_ONLY"
echo "日時:               $(date)"
echo ""

# 確認プロンプト
read -p "データベースを復元してもよろしいですか？既存データが上書きされる可能性があります。(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "ユーザーによって復元がキャンセルされました。"
    exit 0
fi

# PostgreSQLコンテナの実行状態を確認
check_postgres_container

# PostgreSQLの準備完了を待機
wait_for_postgres

# 要求された場合はデータベースを削除
if [ "$CLEAN_DB" = true ]; then
    drop_database
    CREATE_DB=true  # 削除後は強制的に作成
fi

# 要求された場合、または削除された場合はデータベースを作成
if [ "$CREATE_DB" = true ]; then
    create_database
fi

# バックアップファイルの種類を判定して適切に復元
if [[ "$BACKUP_FILE" == *.sql ]]; then
    restore_sql "$BACKUP_FILE"
elif [[ "$BACKUP_FILE" == *.backup ]]; then
    restore_custom "$BACKUP_FILE"
else
    echo "警告: 不明なバックアップファイル形式です。SQL復元を試行します..."
    restore_sql "$BACKUP_FILE"
fi

# データベース情報を表示
echo ""
get_database_info

echo ""
echo "リストア処理が正常に完了しました！"
echo "データベース 'privacyidea' が次のファイルから復元されました: $(basename "$BACKUP_FILE")"

# サービス再起動の推奨
echo ""
echo "推奨事項:"
echo "1. 適切な接続を確保するため、サービスを再起動してください:"
echo "   make restart"
echo "   または: docker compose restart privacyidea"
echo ""
echo "2. 復元後の動作確認:"
echo "   ./debug_tools/scripts/test_postgresql.sh  # データベース接続テスト"
echo "   ./debug_tools/scripts/test_privacyidea.sh # privacyIDEA接続テスト"
echo "   ./debug_tools/scripts/test_radius.sh      # RADIUS認証テスト"
