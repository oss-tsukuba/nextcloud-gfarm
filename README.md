# Nextcloud-Gfarm

## Overview

- Nextcloud container with Gfarm backend storage.
  - it extends the official Nextcloud container image.
  - the base Nextcloud container version can be upgraded.
- This includes an external storage app for Gfarm that enables access to Gfarm file system.
- (OPTIONAL) It is possible to use Gfarm file system as a system data directory by NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1
  - It uses a Gfarm system user for all Nextcloud users.
  - It backs up system files and database to Gfarm automatically.
    - Backup-file of database is encrypted.
  - It restores from Gfarm automatically when local data (docker volume) is empty.
  - Some operations may be slow.
- Reverse proxy is required in front of the Nextcloud in case of https.
  - Docker Compose configuration file example for https is included.

For other details, please refer to
[nextcloud (DOCKER OFFICIAL IMAGE)](https://github.com/docker-library/docs/blob/master/nextcloud/README.md).

## Security Considerations

- Gfarm user's credentials (shared keys or passwords) are stored in Nextcloud's database.
  - Shared keys or passwords are encrypted by a random secret key in Nextcloud configuration file.
- Within Nextcloud container, a local user (www-data) accesses Gfarm mountpoints on behalf of Gfarm users.
- Nextcloud-Gfarm administrators have capability to access Gfarm user's credentials and mounted files within Nextcloud container.
- Once a Gfarm file has been accessed, the filename is stored in Nextcloud's database.
  - The file contents are not stored in the Nextcloud's database.
- For additional Nextcloud information, please refer to Nextcloud official pages.

## Requirements

- [Docker Engine and Docker Compose v2](https://docs.docker.com/engine/install/)
  - Docker Desktop is not required.
- Gfarm configuration file (gfarm2.conf)
  - Gfarm is not required to install on the host OS.
- GNU make
- `/bin/bash`
- openssl command
- curl command

Optional requirements:

- CA certificate files (ex. /etc/grid-security/certificates)

Optional requirements in case of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1:

- Gfarm user configuration (~/.gfarm2rc)
- Gfarm shared key (~/.gfarm_shared_key)
- GSI user key (~/.globus/usercert.pem + ~/.globus/userkey.pem + pass-phrase)
- GSI user proxy certificate (`/tmp/x509up_u<UID>`)
- GSI myproxy server (hostname + password)

## Target Versions

- Nextcloud 23 to 31
- Gfarm 2.7.21 or later
- Gfarm 2.8.x

## Supported architectures

- amd64 (x86_64)
- arm64 (aarch64)

## Supported Gfarm authentication methods

- For external storage
  - GSI + myproxy-logon
  - XOAUTH2 + jwt-agent (for Gfarm 2.8 or later)
  - Gfarm shared key

- For system data directory (NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)
  - Gfarm shared key
    - TLS connection (for Gfarm 2.8 or later)
  - GSI, myproxy-logon
  - GSI, X.509 private key
  - GSI, X.509 proxy

## Quick start

- install [Docker Engine and Docker Compose v2](https://docs.docker.com/engine/install/)
- run `make init` to create `config.env`
  (or run `make init-hpci` for HPCI shared storage)
  - input a password for Nextcloud admin.
    - It is a login password for admin, and also used to restore from the backup.
    - It is stored in `./secrets/nextcloud_admin_password`
  - A password file for MariaDB `./secrets/db_password` is generated automatically.
  - (not recommended, slow) If you want to use a Gfarm directory as Nextcloud system data directory, specify NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1.
  - A symlink `docker-compose.override.yml` is created automatically.
    - it links to `docker-compose.override.yml.https` in case of PROTOCOL=https
    - it links to `docker-compose.override.yml.http` in case of PROTOCOL=http
- edit `config.env` if necessary (see details below)
- create or copy files for your environment
  - copy gfarm2.conf in GFARM_CONF_DIR
  - copy CA files in GSI_CERTIFICATES_DIR
- check and edit `docker-compose.override.yml`
  - It is a symlink.  You need to remove (and copy it from the template) before editing.
- run `make check-config` to check configurations.
- run `make selfsigned-cert-generate` to activate HTTPS when using HTTPS.
  - This is for testing purposes only.  Use an appropriate server certificate.  See below.
- run `make reborn` to create and start containers.
  - If containers exist, these will be recreated.
  - Persistent data (DB, configuration files, and etc.) is not removed.
  - In case of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1, it is necessary to input password of myproxy-logon or grid-proxy-init for a Gfarm system user if not using a shared secret key authentication.
- If not using a self-signed certificate, copy certificate files for HTTPS to `nextcloud-gfarm-revproxy-1:/etc/nginx/certs` volume.
  - NOTE: HTTPS port is disabled when certificate files do not exist.
  - prepare the following files
    - ${SERVER_NAME}.key (SSL_KEY)
    - ${SERVER_NAME}.csr (SSL_CSR)
    - ${SERVER_NAME}.crt (SSL_CERT)
    - and run `sudo docker cp <filename> nextcloud-gfarm-revproxy-1:/etc/nginx/certs/<filename>` to copy a file
  - or write new docker-compose.override.yml and use, for example, acme-companion for nginx-proxy to use Let's Encrypt certificate.  See below.
    - <https://github.com/nginx-proxy/acme-companion>
    - <https://github.com/nginx-proxy/acme-companion/blob/main/docs/Docker-Compose.md>
    - <https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/mariadb/fpm/docker-compose.yml>
- run `make restart@revproxy` if certificate files for HTTPS are updated.
- open the URL in a browser
  - example: `https://<hostname>/`
  - example: `https://<hostname>:<port>/`
- login
  - username: `admin`
  - password: <value of `./secrets/nextcloud_admin_password`>
- Settings -> External storage
  - If you want to allow users to mount Gfarm, enable `Allow users to mount external storage`.
  - To mount a Gfarm directory:
    - select `Add storage` (External storage): Gfarm
    - select Authentication type
    - specify Configuration parameters
    - select `Available for` to allow users or groups. (Administration settings only)
    - press the right button to check and save configurations.

## HTTPS (SSL/TLS) and Certificates and Reverse proxy

Please refer to
[Make your Nextcloud available from the internet](https://github.com/nextcloud/docker/blob/master/README.md#make-your-nextcloud-available-from-the-internet)

docker-compose.override.yml.https is an example to setup
using a reverse proxy and using a self signed certificate.

It is possible to use another reverse proxy by describing
docker-compose.override.yml for your environment.

## Trash

When deleting files, Nextcloud moves them to a trash bin in the local storage.
It may take time or cause storage shortage issues if the file size is large.
You can disable this feature by disable 'Deleted files' app or the following
commands;
```
$ make shell
$ html/occ app:disable files_trashbin
```

## Configuration file (config.env)

You can override the values in `config.env` file with your environment variables.
For details: [Ways to set environment variables in Compose](https://docs.docker.com/compose/environment-variables/set-environment-variables/)

### Configuration format

```text
KEY=VALUE
```

For details of Nextcloud parameters, please refer to
[nextcloud/docker](https://hub.docker.com/_/nextcloud/).

### Mandatory parameters

- NEXTCLOUD_VERSION: Nextcloud version
- SERVER_NAME: server name for this Nextcloud
- PROTOCOL: https or http
- GFARM_CONF_DIR: path to parent directory on host OS for the following files
  - gfarm2.conf: Gfarm configuration file
- NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR: use Gfarm directory as Nextcloud datadir instead of local volume. (1: enable, 0: disable)

### Required parameters when using http

- PROTOCOL: `http` is required
- HTTP_PORT: http port

### Required parameters when using https

- PROTOCOL: `https` is required
- HTTP_PORT: http port (redirect to https port)
- HTTPS_PORT: https port

### Gfarm parameters

Default is specified by `docker-compose.yml`.

- MYPROXY_SERVER: myproxy server (hostname:port) (optional)
- GSI_CERTIFICATES_DIR: CA files for GSI (a directory for public keys for trusted certificate authorities on the host OS)
- TLS_CERTIFICATES_DIR: CA files for TLS (for Gfarm 2.8 or later)
- GSI_PROXY_HOUR: expiration hours of the certificate for grid-proxy-init or myproxy-logon
- XOAUTH2_USER_CLAIM: xoauth2_user_claim for sasl.xoauth2 authentication

### Gfarm parameters only when NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1

- GFARM_USER: Gfarm user name to access GFARM_DATA_PATH and GFARM_BACKUP_PATH
- GFARM_DATA_PATH: Gfarm data directory
  - NOTE: Do not share GFARM_DATA_PATH with other Nextcloud-Gfarm.
- GFARM_BACKUP_PATH: Gfarm backup directory
  - NOTE: Do not share GFARM_BACKUP_PATH with other Nextcloud-Gfarm.
- MYPROXY_USER: username for myproxy server (optional)
- GSI_USER_DIR: path to `~/.globus` on host OS
- GFARM_CONF_USER_DIR: path to parent directory on host OS for the following files (Please make a special directory and copy the files)
  - `gfarm2rc` (optional) (copy from `~/.gfarm2rc`)
  - `gfarm_shared_key` (optional) (copy from `~/.gfarm_shared_key`)
  - `user_proxy_cert` (optional) (copy from `/tmp/x509up_u<UID>`)

### Optional parameters

Default is specified by `docker-compose.yml`.

- NEXTCLOUD_GFARM_UPLOAD_LIMIT: the upload limit (bytes) for big files (0: unlimited, default) (ex. 1073741824)
    - 0 is not recommended.
    - Please determine the limit and announce it to users.
    - If the limit is reached, "An unknown error has occurred" occurs. (HTTP error code 413)
- NEXTCLOUD_GFARM_DEBUG: debug mode (0: disable)
- http_proxy: http_proxy environment variable
- https_proxy: http_proxy environment variable
- no_proxy: comma-separated list of host names should not go through the proxy
- HTTP_ACCESS_LOG: access log (1=enable)
- TZ: TZ environment variable
- NEXTCLOUD_UPDATE: 0 is required in case of version mismatch after restore.
- NEXTCLOUD_FILES_SCAN_TIME: file scan time (crontab format)
- NEXTCLOUD_BACKUP_TIME: backup time (crontab format)
- NEXTCLOUD_TRUSTED_DOMAINS: Nextcloud parameter
- NEXTCLOUD_DEFAULT_PHONE_REGION: Nextcloud parameter
- GFARM_CHECK_ONLINE_TIME: time to check online (crontab format)
- GFARM_CREDENTIAL_EXPIRATION_THRESHOLD: minimum expiration time for Gfarm (sec.)
- GFARM_ATTR_CACHE_TIMEOUT: gfs_stat_timeout for gfarm2fs
- GFARM2FS_LOGLEVEL: loglevel for gfarm2fs
- FUSE_ENTRY_TIMEOUT: entry_timeout for gfarm2fs
- FUSE_NEGATIVE_TIMEOUT: negative_timeout for gfarm2fs
- FUSE_ATTR_TIMEOUT: attr_timeout for gfarm2fs
- TRUSTED_PROXIES: reverse proxy parameter for Nextcloud
  - default: revproxy container IP address
- OVERWRITEHOST: reverse proxy parameter for Nextcloud
- OVERWRITEPROTOCOL: reverse proxy parameter for Nextcloud
- OVERWRITEWEBROOT: reverse proxy parameter for Nextcloud
- OVERWRITECONDADDR: reverse proxy parameter for Nextcloud

## Stop and Start services (all containers)

stop:

```bash
make stop
```

start:

```bash
make restart-withlog
### `ctrl-c` to stop log messages
```

## After updating configurations (config.env)

```bash
make reborn
```

or

```bash
make reborn-withlog
```

## Synchronize files from Gfarm

```bash
make files-scan
```

NOTE: This is ran automatically by NEXTCLOUD_FILES_SCAN_TIME.

## Update Gfarm credential

To copy Gfarm shared key into container:
(for NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)

```bash
### (after updating .gfarm_shared_key)
cp ~/.gfarm_shared_key GFARM_CONF_USER_DIR/gfarm_shared_key
make copy-gfarm_shared_key
make occ-maintenancemode-off
```

To copy GSI user proxy certificate into container:
(for NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)

```bash
### (after executing grid-proxy-init or myproxy-logon on host OS)
cp /tmp/x509up_u${UID} GFARM_CONF_USER_DIR/user_proxy_cert
make copy-globus_user_proxy
make occ-maintenancemode-off
```

To run grid-proxy-init in container:
(for NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)

```bash
make grid-proxy-init-force
make occ-maintenancemode-off
```

To run myproxy-logon in container:
(for NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)

```bash
make myproxy-logon-force
make occ-maintenancemode-off
```

## Use shell of Nextcloud container

Nextcloud user (www-data):

```bash
make shell
```

root user:

```bash
make shell-root
```

## Backup and Restore

Two types are available:

- LOCAL-BACKUP (Backup to a local file)
  - this is a manual backup
  - it backs up `config.env` and `secrets/*`
  - it backs up docker volumes in `make volume-list` that include data, db, nextcloud files, certs and logs (/var/log of nextcloud)

- GFARM-BACKUP (Backup to files on Gfarm filesystem)
  - only available in case of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1
  - it periodically backs up automatically
  - it backs up data, db and nextcloud files
  - it does not back up certs, /var/log of nextcloud and other logs
  - it does not back up `config.env` and `secrets/*`

Nextcloud cannot be accessed during backup.

### Backup by LOCAL-BACKUP

- run `mkdir <OUTPUT_DIRECTORY>`
- run `./volume-backup.sh <OUTPUT_DIRECTORY>`

<OUTPUT_DIRECTORY>/nextcloud-gfarm-backup-YYYYmmdd-HHMM.tar will be created.

### Restore from LOCAL-BACKUP

- run `make down-REMOVE_VOLUMES` if needed.
  - WARNING: Local database will be removed.
- remove `./secrets/*` files and `config.env` if needed.
- run `./volume-restore.sh <INPUT_FILE>`
- If nextcloud container cannot start in case of version mismatch after restore, edit `config.env` and set `NEXTCLOUD_UPDATE=0`, and `make reborn`
- edit `config.env` and set `NEXTCLOUD_UPDATE=1`

### Backup by GFARM-BACKUP

Nextcloud database will be automatically backed up to Gfarm filesystem
according to NEXTCLOUD_BACKUP_TIME.

To back up Nextcloud database manually:

- run `make backup`

To back up configuration files.

- copy `./secrets/*` files and `config.env` to a safe place.

NOTE: `./secrets/nextcloud_admin_password` is also used to encrypt the backup data.  So the same password is required when restoring.  However, `./secrets/nextcloud_admin_password` is not backed up by this function.

### Restore of GFARM-BACKUP

Even if Nextcloud database is broken or lost, you can restore from backup:

- run `make down-REMOVE_VOLUMES` if needed.
  - WARNING: Local database will be removed.
- deploy `certs`, `./secrets/*` files and `config.env` manually.
- run `make reborn`

## Logging

- Nextcloud log: Nextcloud UI -> Logging
  - or /var/log/nextcloud/nextcloud.log in nextcloud container.
  - or `make nextcloud.log` to show logs on the host OS.
  - This is included in the backup.
- run `make logs` to show logs of the nextcloud container.
- run `make logs@<container name>` to show logs of non-nextcloud containers.
- run `make logs-follow` or `make logs-follow@<container name>` to follow logs.
- NOTE: The following logs are not included in the backup.
  (These logs are removed after `make reborn` or `make down`.)
  - logs of non-nextcloud containers.

You can describe docker-compose.override.yml to change logging driver.
(not yet confirmed)

- <https://docs.docker.com/compose/compose-file/compose-file-v3/#logging>
- <https://docs.docker.com/config/containers/logging/configure/>

## Update containers

- update nextcloud-gfarm source
- or update `config.env`
- or update docker-compose.yml
- or run `make build-nocache` to update packages forcibly
- and run `make reborn`

## Upgrade to a newer Nextcloud

- create backup (See `Backup and Restore` section)
- edit `config.env`
  - increase `NEXTCLOUD_VERSION` by exactly 1 from the current major version
    - to show the current version, run `make show-nextcloud-version`
- run `make reborn`

SEE ALSO:
<https://github.com/nextcloud/docker/blob/master/README.md#update-to-a-newer-version>

It is only possible to upgrade one major version at a time.
For example, if you want to upgrade from version 22 to 24, you
need to upgrade to 23 first, and then to 24.

NOTE: Downgrade is not supported.

For example, if the following error occurred, set `NEXTCLOUD_VERSION=22` in `config.env`.

```text
nextcloud_1  | Can't start Nextcloud because the version of the data (23.0.1.2) is higher than the docker image version (22.2.5.1) and downgrading is not supported. Are you sure you have pulled the newest image version?
nextcloud-gfarm_nextcloud_1 exited with code 1
```

NOTE: If the upgrade fails:

Restore NEXTCLOUD_VERSION to the original version and see `Restore` section.

## Warnings displayed on /settings/admin/overview

Follow the warnings.

For example, the following case:

```text
The database is missing some indexes. Due to the fact that adding indexes on big tables could take some time they were not added automatically. By running "occ db:add-missing-indices" those missing indexes could be added manually while the instance keeps running. Once the indexes are added queries to those tables are usually much faster.
Missing index "preferences_app_key" in table "oc_preferences".
```

- run `make shell`
- run `html/occ db:add-missing-indices` (for the above case)

## Change DB password

- (only available in case of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1)
- run `make backup`
- run `make down-REMOVE_VOLUMES`
  - clear password for root user of mariadb
- edit `./secrets/db_password`
- run `make reborn`
  - set new password for root user of mariadb in mariadb container
  - set new password for nextcloud user of mariadb in nextcloud container

NOTE: Password for root user and nextcloud user of mariadb is the same.

NOTE: Nextcloud may not have official instructions on how to change the password.  Therefore, Nextcloud-Gfarm has implemented the change process for the password in `./nextcloud/entrypoint0.sh`.

## Reset Nextcloud admin password

- run `make resetpassword-admin`
- input a new password.
  - `./secrets/nextcloud_admin_password` will be updated.
  - The Password in DB will also be updated.
- run `make reborn` to reflect the password file in container.
- run `make backup` to change the password for backup data.
  - only available in case of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=1


SEE ALSO:

<https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/reset_admin_password.html>

## Using Keycloak to login (nextcloud-oidc-login app)

### Keycloak configurations

(SEE ALSO: <https://github.com/pulsejet/nextcloud-oidc-login>)

- Summary
  - Create new realm
  - Create new client
    - `Access Type`:`confidential`
    - `Valid Redirect URI`: `https://<Nextcloud name>/*`
    - `ID Token Signature Algorithm`: `RS256`
    - Please check and copy (and paste): `Credentials` -> 'Secret'
  - Set quota attributes (`Mapper Type`) (optional)
    - Add `User Attribute`
      - `Name`,`User Attribute`, and `Token Claim Name` : `ownCloudQuota`
      - `Claim JSON Type` : `String`
    - Add `User Client Role`
      - `Name` and `Token Claim Name` : `ownCloudGroups`
      - select your Client ID
      - `Claim JSON Type` : `String`
    - Edit `Attributes` for each user
      - `Key` : `ownCloudQuota`
      - `Value` : your preferred limit (in bytes)
  - Add users

### Nextcloud-Gfarm configurations

- config.env (additional parameters)

```text
KEYCLOAK_PROTOCOL=<http or https>
KEYCLOAK_PORT=...
KEYCLOAK_REALM=...
# or OIDC_LOGIN_URL=...  (when using non Keycloak)
OIDC_LOGIN_ENABLE=1
OIDC_LOGIN_CLIENT_ID=...
OIDC_LOGIN_CLIENT_SECRET=...
OIDC_LOGIN_DEFAULT_QUOTA=1000000000
```

- Details, and other parameters: `nextcloud/oidc.config.php.tmpl`
  - OIDC_LOGIN_DEFAULT_QUOTA: 0 or -1 means `Unlimited`
    - If you want to allow Nextcloud to manage quotas, comment out the line of `nextcloud/oidc.config.php.tmpl`.
- and `make reborn`

## For developers

- For Gfarm docker/dev environment
  - run `ln -s <path to gfarm/docker/dev/mnt/COPY_DIR> /work/gfarm-dev`
  - and run `mkdir /work/nextcloud-gfarm-home/` (change to your ownership)
  - and run `make init-dev`
  - and run `./copy_home_files.sh` to copy files into containers
- or create `template-orverride.env` for your environment, and run `make init`
- To use apt-cacher-ng, add "jwt-server,www.nextcloud.com,www.startpage.com,www.eff.org,www.edri.org" to no_proxy

- How to update Nextcloud-Gfarm version
  - update `version.sh`
  - `git tag -a <VERSION> -m 'v<VERSION>'`
  - `git push origin <VERSION>`
