# Gfarm 対応 Nextcloud コンテナ

本リポジトリの内容物は Gfarm 上のデータに簡便にアクセス可能な Nextcloud コンテナを作成するための設定ファイル群です。
Gfarm 対応 Nextcloud コンテナでは、Web UI 等から Nextcloud 上のファイルを操作することで Gfarm 上のファイルを透過的に操作できます。


# 利用方法

Gfarm に Nextcloud で使用するユーザを作成し、その Gfarm ユーザが利用できる Gfarm 上の任意のパスにデータ保存用ディレクトリとシステムバックアップ用ディレクトリを作成してください。
Gfarm の設定ファイル gfarm2.conf、gfarm2rc と共有鍵 gfarm_shared_key を用意してください。

Docker Compose をインストールし、環境変数 PATH に追加してください。

その後、下記を実行してください。

```
$ git clone <URL>
$ cd nextcloud-gfarm
$ cp /path/to/gfarm2.conf .
$ cp /path/to/gfarm2rc .
$ cp /path/to/gfarm_shared_key .
$ vi admin_password
$ vi db_password
$ cp docker-compose.override.yml.sample docker-compose.override.yml
$ vi docker-compose.override.yml
$ vi nextcloud.env
$ sudo docker-compose build --pull nextcloud
$ sudo docker-compose up -d nextcloud
```

admin_password は Nextcloud 管理者のパスワード、db_password はデータベースサーバのパスワードです。
各ファイルにパスワードを直接記載してください。

docker-compose.override.yml は docker-compose.yml の設定をオーバーライドするための設定ファイルです。
書式は Docker Compose 公式ドキュメントを参照してください。
docker-compose.override.yml の下記項目を必要に応じて変更してください。

- NEXTCLOUD_VERSION
- GFARM_SRC_URL
- GFARM2FS_SRC_URL

NEXTCLOUD_VERSION はベースとする Nextcloud の Docker イメージのバージョンです。
GFARM_SRC_URL はビルドに用いる Gfarm のソースコードの URL、GFARM2FS_SRC_URL はビルドに用いる gfarm2fs のソースコードの URL です。

nextcloud.env は Gfarm 対応 Nextcloud で利用する環境変数の設定ファイルです。
書式は Docker Compose 公式ドキュメントの env_file の項目について参照してください。
nextcloud.env に下記項目を設定してください。

- GFARM_USER
- GFARM_DATA_PATH
- GFARM_BACKUP_PATH
- NEXTCLOUD_TRUSTED_DOMAINS
- NEXTCLOUD_BACKUP_TIME

GFARM_USER は先ほど作成した Gfarm のユーザを指定してください。
GFARM_DATA_PATH は Gfarm 上のデータ保存用ディレクトリ、GFARM_BACKUP_PATH はシステムバックアップ用ディレクトリを指定してください。
NEXTCLOUD_TRUSTED_DOMAINS は Web ブラウザでアクセスする際に localhost 以外のドメイン名を利用するなら指定してください。
NEXTCLOUD_BACKUP_TIME は Nextcloud のシステム全体をバックアップする時間を指定してください。
crontab における時間指定と同様の形式です。


# 設定項目

## nextcloud.env

nextcloud.env は Gfarm 対応 Nextcloud で利用する環境変数の設定ファイルです。
必要に応じて設定を変更してください。
書式は Docker Compose 公式ドキュメントの env_file の項目について参照してください。
設定可能な項目は下記のとおりです。

- NEXTCLOUD_ADMIN_USER
    - Nextcloud の管理者アカウント名です。この名前のアカウントで Nextcloud にログインできます。
    - 初期値は admin です。
- NEXTCLOUD_ADMIN_PASSWORD_FILE
    - コンテナ内で Nextcloud の管理者アカウントのパスワードを格納したファイルが配置されるパスです。
    - 初期値は /run/secrets/admin_password です。
- NEXTCLOUD_LOG_PATH
    - コンテナ内で Nextcloud のログを配置するパスです。
    - 初期値は /var/log/nextcloud.log です。
- NEXTCLOUD_TRUSTED_DOMAINS
    - Nextcloud がアクセスを許可するドメイン名を指定します。 指定したドメイン名の URL で Nextcloud にアクセスできます。指定していないドメイン名ではアクセスできません。
    - 初期値はありません。
- NEXTCLOUD_BACKUP_TIME
    - Nextcloud とデータベースをバックアップする時刻です。crontab と同じ書式です。
    - 初期値は 0 3 * * * です。
- MYSQL_DATABASE
    - データベースサーバで Nextcloud 用に作成するデータベースの名前です。
    - 初期値は nextcloud です。
- MYSQL_USER
    - データベースサーバで Nextcloud 用に作成するアカウントの名前です。
    - 初期値は nextcloud です。
- MYSQL_PASSWORD_FILE
    - データベースサーバで Nextcloud 用に作成するアカウントのパスワードです。
    - 初期値は /run/secrets/db_password です。
- MYSQL_HOST
    - データベースサーバのホスト名です。
    - 初期値は mariadb です。
- GFARM_USER
    - Nextcloud から Gfarm にアクセスする際に使用するユーザです。各自の環境で利用するユーザを指定してください。
    - 初期値は user1 です。
- GFARM_DATA_PATH
    - Nextcloud のファイルデータ本体を保存するための Gfarm 上のディレクトリです。GFARM_USER で指定したユーザでアクセス可能な Gfarm 上のディレクトリを指定してください。また Gfarm 上のそのパスにディレクトリを作成しておいてください。
    - 初期値は /home/user1/nextcloud-data です。
- GFARM_BACKUP_PATH
    - Nextcloud がシステムのバックアップを保存する際に使用する Gfarm 上のディレクトリです。GFARM_USER で指定したユーザでアクセス可能な Gfarm 上のディレクトリを指定してください。また Gfarm 上のそのパスにディレクトリを作成しておいてください。
    - 初期値は /home/user1/nextcloud-backup です。
- GFARM_ATTR_CACHE_TIMEOUT
    - Nextcloud から Gfarm を使用する際のファイル・ディレクトリ属性のキャッシュ有効時間です。
    - 初期値は 180 秒です。
- TZ
    - コンテナ内で使用するタイムゾーンを指定してください。
    - 初期値は Asia/Tokyo です。
- FUSE_ENTRY_TIMEOUT
    - Nextcloud から gfarm2fs を使用する際のディレクトリエントリのキャッシュ有効時間です。
    - 初期値は 180 秒です。
- FUSE_NEGATIVE_TIMEOUT
    - Nextcloud から gfarm2fs を使用する際のディレクトリエントリのネガティブキャッシュ有効時間です。
    - 初期値は 5 秒です。
- FUSE_ATTR_TIMEOUT
    - Nextcloud から gfarm2fs を使用する際のファイル・ディレクトリ属性のキャッシュ有効時間です。
    - 初期値は 180 秒です。


以下は通常変更不要な項目です。

- NEXTCLOUD_ADMIN_PASSWORD_FILE
- MYSQL_DATABASE
- MYSQL_USER
- MYSQL_PASSWORD_FILE
- MYSQL_HOST


## mariadb.env

mariadb.env はデータベースの環境変数の設定ファイルです。
これらの値は通常変更不要ですが、nextcloud.env で対応する値を変更する場合は設定を変更してください。
書式は Docker Compose 公式ドキュメントの env_file の項目について参照してください。
設定可能な項目は下記のとおりです。

- MYSQL_DATABASE
    - データベースサーバで Nextcloud 用に作成するデータベースの名前です。
    - 初期値は nextcloud です。
- MYSQL_USER
    - データベースサーバで Nextcloud 用に作成するアカウントの名前です。
    - 初期値は nextcloud です。
- MYSQL_PASSWORD_FILE
    - データベースサーバで Nextcloud 用に作成するアカウントのパスワードです。
    - 初期値は /run/secrets/db_password です。
- MYSQL_ROOT_PASSWORD_FILE
    - データベースサーバで作成する管理者アカウントのパスワードです。
    - 初期値は /run/secrets/db_password です。


## docker-compose.override.yml

docker-compose.override.yml は docker-compose.yml の設定を上書きするためのファイルです。
必要に応じて設定を変更してください。
設定可能な項目は下記のとおりです。
書式は Docker Compose 公式ドキュメントを参照してください。

- NEXTCLOUD_VERSION
    - Gfarm 対応 Nextcloud コンテナでベースにする Nextcloud の Docker イメージのバージョンです。Nextcloud のバージョンについては Nextcloud 公式を参照してください。
- GFARM_SRC_URL
    - Gfarm のソースコードを示す URL です。指定した URL の Gfarm をビルドして Nextcloud イメージに組み込みます。URL は zip 圧縮されたソースコードのみ対応します。
- GFARM2FS_SRC_URL
    - gfarm2fs のソースコードを示す URL です。指定した URL の gfarm2fs をビルドして Nextcloud イメージに組み込みます。URL は zip 圧縮されたソースコードのみ対応します。


# コンテナ作成

Nextcloud コンテナを作成する場合、次のいずれかのケースとしてシステムが構築されます。

1. システム全構築
2. ボリューム再利用
3. バックアップからのレストア


## システム全構築

コンテナを初回作成する場合や、バックアップとボリュームがない状態でコンテナを作成する場合です。
Nextcloud のシステムを最初から全てセットアップします。


## ボリューム再利用

Nextcloud とデータベースのシステムは Docker ボリューム上に配置されており、ボリュームが存在すれば次回コンテナ作成時にも前回の状態を引き継いで Nextcloud を利用できます。


## バックアップからのレストア

Gfarm 対応 Nextcloud コンテナはシステム全体のバックアップを定期的に Gfarm 上に作成します。
ボリュームが壊れた場合、あるいは誤ってボリュームを削除した場合などにシステムがバックアップされていれば、コンテナ作成時に前回のシステムをレストアします。
ただ、バックアップ以降に Nextcloud システムの操作を行っていた場合、ファイルそのものに対する変更は保持されますが、Nextcloud の設定やメタデータ(バージョン履歴など)は復元されない場合があります。


# Nextcloud のアップデート

Nextcloud のバージョンをアップデートしたい場合は下記の手順を実施してください。

```
$ vi docker-compose.override.yml
(Nextcloud イメージのバージョン編集)
$ sudo docker-compose build --pull nextcloud
$ sudo docker-compose up -d nextcloud
```

アップグレードした後、Nextcloud のコマンド (occ) を実行するように表示されることがあります。
下記のようにコンテナホスト上で表示されたコマンドを実行してください。

```
$ sudo docker-compose exec --user www-data nextcloud php /var/www/html/occ <occ subcommand>
```

Nextcloud コンテナ内で実行する場合は下記のように実行してください。

```
$ sudo docker-compose exec nextcloud /bin/bash
$ su -s /bin/bash www-data
$ php /var/www/html/occ <occ subcommand>
```

# 注意事項

## Gfarm 上で変更したファイルの反映

Nextcloud を介さずに Gfarm 上で直接ファイルを作成・削除した場合、その状態が Nextcloud に反映されるまでに 30 分かかります。
