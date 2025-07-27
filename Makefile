# FreeRADIUS + PrivacyIDEA Docker Environment Makefile

.PHONY: help up stop restart clean-stop init-certs update-certs clean-data clean-images clean-all debug-up debug-to-prod debug-shell prod-up

# デフォルトターゲット
help:
	@echo "FreeRADIUS + PrivacyIDEA Docker Environment"
	@echo ""
	@echo "使用可能なコマンド:"
	@echo "  make up           - サービスを起動 (本番モード)"
	@echo "  make stop         - サービスを停止 (コンテナ保持)"
	@echo "  make clean-stop   - サービスを停止してコンテナを削除"
	@echo "  make restart      - サービスを再起動"
	@echo "  make debug-up     - デバッグモードで起動 (Flask DEBUG=true, FreeRADIUS -X)"
	@echo "  make debug-to-prod - デバッグモードを停止し本番モードに戻る"
	@echo "  make debug-shell  - デバッグツールシェルに接続"
	@echo "  make init-certs   - 証明書とenckeyを初回作成"
	@echo "  make update-certs - 証明書のみ更新 (enckeyは保持)"
	@echo "  make clean-data   - データとログを削除 (証明書含む)"
	@echo "  make clean-images - プロジェクトイメージを削除"
	@echo "  make clean-all    - すべてのリソースを削除"
	@echo "  make logs         - サービスのログを表示"
	@echo "  make freeradius-logs - FreeRADIUSログを表示（リアルタイム）"
	@echo "  make freeradius-logs-recent - FreeRADIUSの最新ログを表示"
	@echo "  make status       - コンテナの状態を確認"
	@echo "  make test-auth    - RADIUS認証テスト"

# サービス起動（本番モード）
up:
	@echo "🚀 サービスを起動しています（本番モード）..."
	docker compose --profile production up -d
	@echo "✅ サービスが起動しました（本番モード）"
	@echo "   PrivacyIDEA管理画面: http://localhost"
	@echo "   RADIUS認証ポート: 1812/UDP"

# サービス停止
stop:
	@echo "⏹️  サービスを停止しています..."
	docker compose stop || true
	docker compose --profile production stop || true
	docker compose --profile debug stop || true
	@echo "✅ サービスが停止しました"

# サービス停止（コンテナ削除）
clean-stop:
	@echo "🗑️  サービスを停止してコンテナを削除しています..."
	docker compose --profile production down || true
	docker compose --profile debug down || true
	docker compose down || true
	@echo "✅ サービスが停止し、コンテナが削除されました"

# サービス再起動
restart: clean-stop up
	@echo "✅ サービスが再起動しました"

debug-up: stop
	@echo "🚀 デバッグモードでサービスを起動しています..."
	@sleep 3
	@echo "   デバッグモードで起動しています..."
	docker compose --profile debug up -d
	@echo "✅ デバッグモードでサービスが起動しました"
	@echo "   PrivacyIDEA管理画面: http://localhost"
	@echo "   RADIUS認証ポート: 1812/UDP (デバッグモード)"
	@echo "   Flask Debug: ON (FLASK_DEBUG=true)"
	@echo "   PrivacyIDEA Log Level: DEBUG"
	@echo "   FreeRADIUS: デバッグモード (-X)"
	@echo "   FreeRADIUSデバッグログ: make freeradius-logs"
	@echo "   デバッグツール: make debug-shell"

debug-to-prod: stop up
	@echo "✅ デバッグモードが停止し、本番モードに戻りました"

init-certs:
	@echo "🔐 証明書とenckeyを初回作成しています..."
	@if [ -f "./privacyidea/certs/enckey" ]; then \
		echo "⚠️  enckey ファイルが既に存在します"; \
		echo "   既存のenckeyを保持します"; \
	else \
		echo "   新しいenckeyを作成します"; \
	fi
	./scripts/generate_cert.sh
	@echo "✅ 証明書とenckeyの作成が完了しました"

update-certs:
	@echo "🔐 証明書を更新しています (enckeyは保持)..."
	@if [ ! -f "./privacyidea/certs/enckey" ]; then \
		echo "❌ enckey ファイルが存在しません"; \
		echo "   初回セットアップの場合は 'make init-certs' を実行してください"; \
		exit 1; \
	fi
	# enckeyをバックアップ
	cp ./privacyidea/certs/enckey ./privacyidea/certs/enckey.backup
	# 証明書を再生成
	./scripts/generate_cert.sh
	# enckeyを復元
	mv ./privacyidea/certs/enckey.backup ./privacyidea/certs/enckey
	@echo "✅ 証明書の更新が完了しました (enckeyは保持)"

# データとログの削除
clean-data:
	@echo "🗑️  データとログを削除しています..."
	@echo "⚠️  この操作により以下が削除されます:"
	@echo "   - データベースデータ (postgresql/data/)"
	@echo "   - SSL証明書 (nginx/certs/, freeradius/certs/, privacyidea/certs/)"
	@echo "   - ログファイル (debug_tools/logs/)"
	@echo "   - このプロジェクトのコンテナのみ"
	@read -p "続行しますか? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	# 全プロファイルを含むコンテナを停止・削除
	docker compose --profile debug down -v --remove-orphans
	# プロジェクト固有のイメージを削除（未使用のもののみ）
	-docker image prune -f 2>/dev/null || true
	sudo rm -rf ./postgresql/data/*
	rm -rf ./nginx/certs/*
	rm -rf ./freeradius/certs/*
	rm -rf ./privacyidea/certs/*
	rm -rf ./debug_tools/logs/*
	@echo "✅ データとログの削除が完了しました"

# すべてのリソースを削除
clean-all:
	@echo "🗑️  すべてのリソースを削除しています..."
	@echo "⚠️  この操作により以下が削除されます:"
	@echo "   - データベースデータ、SSL証明書、ログファイル"
	@echo "   - このプロジェクトのコンテナとイメージ"
	@read -p "本当にすべて削除しますか? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	$(MAKE) clean-data clean-images
	@echo "✅ すべてのリソースの削除が完了しました"

# プロジェクト固有のイメージ削除（高度なオプション）
clean-images:
	@echo "🗑️  このプロジェクトで使用されたイメージを削除しています..."
	@echo "⚠️  以下のイメージが削除対象です:"
	@docker compose config --images 2>/dev/null | sort | uniq || echo "   docker-compose.yml を確認してください"
	@read -p "これらのイメージを削除しますか? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	# プロジェクト固有のコンテナとイメージのみ削除
	docker compose --profile production down --rmi all --remove-orphans || true
	docker compose --profile debug down --rmi all --remove-orphans || true
	docker compose down --rmi all --remove-orphans || true
	@echo "✅ プロジェクトイメージの削除が完了しました"

# ログ表示
logs:
	@echo "📋 サービスのログを表示しています..."
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		echo "   デバッグモードのログ:"; \
		docker compose --profile debug logs -f; \
	else \
		echo "   本番モードのログ:"; \
		docker compose --profile production logs -f; \
	fi

# コンテナ状態確認
status:
	@echo "📊 コンテナの状態:"
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		echo "   デバッグモード:"; \
		docker compose --profile debug ps; \
	else \
		echo "   本番モード:"; \
		docker compose ps; \
	fi
	@echo ""
	@echo "🏥 ヘルスチェック:"
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 開発用コマンド
dev-setup: init-certs debug-up
	@echo "🚀 開発環境のセットアップが完了しました"
	@echo "   PrivacyIDEA管理画面: http://localhost"
	@echo "   @echo "   RADIUS認証テスト: make test-auth""
	@echo "   デバッグツール: docker exec -it debug_tools bash"
	@echo "   本番モードに戻る: make debug-to-prod"

test-auth:
	@echo "🔐 RADIUS認証テストを実行しています..."
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		echo "   デバッグモードでテスト実行..."; \
		echo "   注意: TOTPコードは時間依存のため、有効なコードが必要です"; \
		docker exec debug_tools perl /debug/scripts/test_radius_totp.pl user01 pass01 000000 freeradius-debug; \
	elif [ $$(docker ps -q -f name=FreeRADIUS) ]; then \
		echo "   本番モードでTOTP認証テスト..."; \
		echo "   注意: TOTPコードは時間依存のため、有効なコードが必要です"; \
		perl scripts/test_radius_totp.pl user01 pass01 000000 localhost; \
	else \
		echo "❌ FreeRADIUSコンテナが起動していません"; \
		echo "   'make up' または 'make debug-up' でサービスを起動してください"; \
	fi

freeradius-logs:
	@echo "📋 FreeRADIUSログを表示しています..."
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		echo "   デバッグモードのログ:"; \
		docker compose --profile debug logs -f freeradius-debug; \
	elif [ $$(docker ps -q -f name=FreeRADIUS) ]; then \
		echo "   本番モードのログ:"; \
		docker compose --profile production logs -f freeradius; \
	else \
		echo "❌ FreeRADIUSコンテナが起動していません"; \
	fi

freeradius-logs-recent:
	@echo "📋 FreeRADIUSの最新ログを表示しています..."
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		docker logs --tail=50 $$(docker ps --filter "name=FreeRADIUS-Debug" --format "{{.Names}}"); \
	elif [ $$(docker ps -q -f name=FreeRADIUS) ]; then \
		docker logs --tail=50 $$(docker ps --filter "name=FreeRADIUS" --format "{{.Names}}"); \
	else \
		echo "❌ FreeRADIUSコンテナが起動していません"; \
	fi

debug-shell:
	@echo "🔧 デバッグツールシェルに接続しています..."
	@if [ $$(docker ps -q -f name=debug_tools) ]; then \
		docker exec -it debug_tools bash; \
	else \
		echo "❌ debug_toolsコンテナが起動していません"; \
		echo "   'make debug-up' でデバッグツールを起動してください"; \
	fi

# 本番環境用起動
prod-up: init-certs up
	@echo "🏭 本番環境モードでサービスが起動しました"
