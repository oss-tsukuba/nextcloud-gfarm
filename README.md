# nextcloud-gfarm

## Overview

- Nextcloud container with Gfarm as back-end storage.
- Use one Gfarm user and the data directory for multiple Nextcloud users.
- Back up to Gfarm automatically.
    - Backup-file of database is encrypted.
- Restore from Gfarm automatically when local data (docker volume) is empty.
- Reverse proxy is required in front of this Nextcloud if you want to use https.

For other details, please refer to
[nextcloud/docker](https://hub.docker.com/_/nextcloud/).

## Requirements

- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/)
- GNU make
- gfarm2.conf

Optional:

- Gfarm user configuration (~/.gfarm2rc)
- Gfarm shared key (~/.gfarm_shared_key)
- GSI user key (~/.globus/usercert.pem + ~/.globus/userkey.pem + pass-phrase)
- GSI user proxy certificate (`/tmp/x509up_u<UID>`)
- GSI myproxy server (hostname + password)

## Quick start

- install Docker
- install Docker Compose
- create and edit db_password file
- create and edit nextcloud_admin_password file
- create and edit .env file (see below)
    - specify Gfarm configuration
    - select Gfarm authentication method
- create docker-compose.override.yml
    - example: `ln -s docker-compose.override.yml.https.selfsigned docker-compose.override.yml`
    - or use one of other docker-compose.override.yml.*
    - or write docker-compose.override.yml for your environment
- run `make reborn-withlog`
- input password of myproxy-logon or grid-proxy-init for Gfarm
  authentication method (when not using .gfarm_shared_key)
- open the URL in a browser
    - example: https://<hostname>/
- login
    - username: `admin`
    - password: `<value of nextcloud_admin_password>`

## HTTPS and Certificates and Reverse proxy

Please refer to
[Make your Nextcloud available from the internet](https://github.com/nextcloud/docker/blob/master/README.md#make-your-nextcloud-available-from-the-internet)

docker-compose.override.yml.https.selfsigned is an example to setup
using a reverse proxy and using self signed certificates.

## Configuration file (.env)

example:

```
NEXTCLOUD_VERSION=23
SERVER_NAME=client1.local
HTTP_PORT=58080
HTTPS_PORT=58443
OVERWRITEHOST=client1.local:58443
OVERWRITEPROTOCOL=https
GFARM_USER=hpciXXXXXX
GFARM_DATA_PATH=/home/hpXXXXXX/hpciXXXXXX/nextcloud/data
GFARM_BACKUP_PATH=/home/hpXXXXXX/hpciXXXXXX/nextcloud/backup
GRID_PROXY_HOURS=168
GFARM2_CONF=/work/gfarm-conf/gfarm2.conf
GRID_CERTIFICATES=/work/gfarm-conf/certificates
MYPROXY_SERVER=portal.hpci.nii.ac.jp:7512
MYPROXY_USER=hpciXXXXXX
```

configuration format:

```
KEY=VALUE
```

For details of Nextcloud parameters, please refer to
[nextcloud/docker](https://hub.docker.com/_/nextcloud/).

mandatory parameters:

- NEXTCLOUD_VERSION: Nextcloud version
- SERVER_NAME: server name for this Nextcloud
- GFARM_USER: Gfarm user name
- GFARM_DATA_PATH: Gfarm data directory
    - NOTE: Do not share GFARM_DATA_PATH with other nextcloud-gfarm.
- GFARM_BACKUP_PATH: Gfarm backup directory
    - NOTE: Do not share GFARM_BACKUP_PATH with other nextcloud-gfarm.
- GFARM2_CONF: path to gfarm2.conf on host OS

Gfarm authentication parameters (specify only required items)
(default values are listed in docker-compose.yml):

- GFARM_SHARED_KEY: path to .gfarm_shared_key on host OS
- GRID_CERTIFICATES: path to /etc/grid-security/certificates on host OS
- GRID_DOT_GLOBUS_DIR: path to .globus on host OS
- GRID_USER_PROXY_CERT: path to /tmp/x509up_u???? created on host OS
- MYPROXY_SERVER: myproxy server (hostname:port)
- MYPROXY_USER: username for myproxy server
- GRID_PROXY_HOUR: hours for grid-proxy-init or myproxy-logon
- GFARM2_CONF_USER: path to .gfarm2rc on host OS

optional parameters (default values are listed in docker-compose.yml):

- HTTP_PORT: http port number (redirect to https)
- HTTPS_PORT: https port number
- NEXTCLOUD_GFARM_DEBUG: debug mode
- http_proxy: http_proxy environment variable
- https_proxy: http_proxy environment variable
- TZ: TZ environment variable
- NEXTCLOUD_FILES_SCAN_TIME: file scan time (crontab format)
- NEXTCLOUD_BACKUP_TIME: backup time (crontab format)
- NEXTCLOUD_TRUSTED_DOMAINS: Nextcloud parameter
- NEXTCLOUD_DEFAULT_PHONE_REGION: Nextcloud parameter
- GFARM_CHECK_ONLINE_TIME: time to check online (crontab format)
- GFARM_CREDENTIAL_EXPIRATION_THRESHOLD: minimum expiration time for Gfarm (sec.)
- GFARM_ATTR_CACHE_TIMEOUT: gfs_stat_timeout for gfarm2fs
- FUSE_ENTRY_TIMEOUT: entry_timeout for gfarm2fs
- FUSE_NEGATIVE_TIMEOUT: negative_timeout for gfarm2fs
- FUSE_ATTR_TIMEOUT: attr_timeout for gfarm2fs
- OVERWRITEHOST: reverse proxy parameter for Nextcloud
- OVERWRITEPROTOCOL: reverse proxy parameter for Nextcloud
- OVERWRITEWEBROOT: reverse proxy parameter for Nextcloud
- OVERWRITECONDADDR: reverse proxy parameter for Nextcloud

## Stop and Start

stop:

```
make stop
```

start:

```
make restart-withlog
```

## Update credential

To copy Gfarm shared key:

```
### after updating .gfarm_shared_key on host OS
make copy-gfarm_shared_key
make occ-maintenancemode-off
```

To copy GSI user proxy certificate:

```
### after running grid-proxy-init or myproxy-logon on host OS
make copy-globus_user_proxy
make occ-maintenancemode-off
```

To run grid-proxy-init in container:

```
make grid-proxy-init-force
make occ-maintenancemode-off
```

To run myproxy-logon in container:

```
make myproxy-logon-force
make occ-maintenancemode-off
```

## Use shell of Nextcloud container

Nextcloud user (www-data):

```
make shell
```

root user:

```
make shell-root
```

## Backup

Nextcloud database will be automatically backed up according to
NEXTCLOUD_BACKUP_TIME.

To back up manually:

```
make backup
```

## Restore

When Nextcloud database is broken, you can restore from backup data:

```
### WARNING: local database is removed.
make down-REMOVE_VOLUMES
make reborn-withlog
```

## Logging

- Nextcloud log: Nextcloud UI -> Logging
    - or /var/www/html/nextcloud.log in container.
    - This is included in the backup.
- `make logs` for containers
    - NOTE: This is not included in the backup.
- /var/log/* in Nextcloud container
    - NOTE: This is not included in the backup.

## Update to a newer Nextcloud

- run `make backup`
- change NEXTCLOUD_VERSION
- run `make reborn-withlog`

NOTE:

https://github.com/nextcloud/docker/blob/master/README.md#update-to-a-newer-version

It is only possible to upgrade one major version at a time.
For example, if you want to upgrade from version 14 to 16, you will
have to upgrade from version 14 to 15, then from 15 to 16.
