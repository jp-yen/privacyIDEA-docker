# rlm_perl.ini について

## 重要な注意事項

**⚠️ このディレクトリにrlm_perl.iniファイルを配置しないでください**

## 理由

- `rlm_perl.ini`ファイルをマウントすると、FreeRADIUSコンテナの起動時にスクリプトによって自動的に書き換えられます
- カスタムファイルをマウントすると、起動プロセスが正常に完了しない場合があります
- コンテナ内のデフォルトファイルが環境変数に基づいて適切に設定されます

## デフォルト設定

FreeRADIUSコンテナは以下の環境変数を使用してrlm_perl.iniを自動生成します：

- `PRIVACYIDEA_URL`: PrivacyIDEAのURL（デフォルト: http://privacyidea:8080/validate/check）
- `SSL_CHECK`: SSL証明書の検証（デフォルト: false）
- `DEBUG`: デバッグモード（デフォルト: false）

## カスタマイズが必要な場合

rlm_perl.iniをカスタマイズしたい場合は：

1. 環境変数（.env）で設定を調整する
2. カスタムDockerイメージを作成する
3. コンテナ起動後にファイルを手動で編集する

## 参考情報

- docker-compose.ymlではrlm_perl.iniをマウントしないように設定済み
- 詳細は[privacyidea-freeradius](https://github.com/gpappsoft/privacyidea-freeradius)を参照
