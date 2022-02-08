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
    - v1 : https://docs.docker.com/compose/install/
    - v2 (Recommended): https://docs.docker.com/compose/cli-command/#install-on-linux
- GNU make
- Gfarm configuration file (gfarm2.conf)

Optional:

- Gfarm user configuration (~/.gfarm2rc)
- Gfarm shared key (~/.gfarm_shared_key)
- GSI user key (~/.globus/usercert.pem + ~/.globus/userkey.pem + pass-phrase)
- GSI user proxy certificate (`/tmp/x509up_u<UID>`)
- GSI myproxy server (hostname + password)

## Quick start

- install Docker
- install Docker Compose
- create a password file for MariaDB: ./secrets/db_password
  - and run: `chmod 600 ./secrets/db_password`
  - (used by Nextcloud to connect MariaDB)
- create a password file for Nextcloud admin: ./secrets/nextcloud_admin_password
  - and run: `chmod 600 ./secrets/nextcloud_admin_password`
  - (to be entered at the Nextcloud login screen) (username: admin)
- create and edit .env file (see details below)
    - specify Gfarm configuration
    - select Gfarm authentication method
    - server name
- create docker-compose.override.yml
    - example: `ln -s docker-compose.override.yml.https docker-compose.override.yml`
    - or use one of other docker-compose.override.yml.*
    - or write docker-compose.override.yml for your environment
- run `make config` to check configurations.
- run `make reborn-withlog`
- input password of myproxy-logon or grid-proxy-init for Gfarm
  authentication method (when not using .gfarm_shared_key)
- `ctrl-c` to stop output of `make reborn-withlog`
- copy certificate files for HTTPS to `nextcloud-gfarm-revproxy-1:/etc/nginx/certs` volume when using docker-compose.override.yml.https
    - NOTE: HTTPS port is diabled when certificate files do not exist.
    - prepare the following files
        - ${SERVER_NAME}.key (SSL_KEY)
        - ${SERVER_NAME}.csr (SSL_CSR)
        - ${SERVER_NAME}.crt (SSL_CERT)
        - and use `sudo docker cp <filename> nextcloud-gfarm-revproxy-1:/etc/nginx/certs/<filename>` to copy a file
    - or `make selfsigned-cert-generate` to generate and copy self-signed certificate
    - or (unsurveyed:) use acme-companion for nginx-proxy to use Let's Encrypt certificate and create new docker-compose.override.yml
        - https://github.com/nginx-proxy/acme-companion
        - https://github.com/nginx-proxy/acme-companion/blob/main/docs/Docker-Compose.md
        - https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/mariadb/fpm/docker-compose.yml
    - or etc.
- run `make restart-revproxy` after certificate files for HTTPS are updated.
- open the URL in a browser
    - example: `https://<hostname>/`
- login
    - username: `admin`
    - password: `<value of nextcloud_admin_password>`

## HTTPS (SSL/TLS) and Certificates and Reverse proxy

Please refer to
[Make your Nextcloud available from the internet](https://github.com/nextcloud/docker/blob/master/README.md#make-your-nextcloud-available-from-the-internet)

docker-compose.override.yml.https is an example to setup
using a reverse proxy and using self signed certificates.

You can use other reverse proxy and describe
docker-compose.override.yml for the environment.

## Configuration file (.env)

example (connect to HPCI shared storage):

```
NEXTCLOUD_VERSION=23
SERVER_NAME=client1.local
PROTOCOL=https
HTTPS_PORT=58443
GFARM_USER=hpciXXXXXX
GFARM_DATA_PATH=/home/hpXXXXXX/hpciXXXXXX/nextcloud/data
GFARM_BACKUP_PATH=/home/hpXXXXXX/hpciXXXXXX/nextcloud/backup
GFARM_CONF_DIR=/work/gfarm-conf/
GSI_CERTIFICATES_DIR=/etc/grid-security/certificates
#GSI_CERTIFICATES_DIR=/work/gfarm-conf/certificates
MYPROXY_SERVER=portal.hpci.nii.ac.jp:7512
MYPROXY_USER=hpciXXXXXX
GSI_PROXY_HOURS=168
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
- GFARM_CONF_DIR: path to parent directory on host OS for the followin files
     - gfarm2.conf: Gfarm configuration file

Gfarm parameters (if necessary)
(default values are listed in docker-compose.yml):

- GFARM_CONF_USER_DIR: path to parent directory on host OS for the following files (Please make a special directory and copy the files)
    - gfarm2rc (optional) (copy from `~/.gfarm2rc`)
    - gfarm_shared_key (optional) (copy from `~/.gfarm_shared_key`)
    - user_proxy_cert (optional) (copy from `/tmp/x509up_u<UID>`)
- GSI_CERTIFICATES_DIR: `/etc/grid-security/certificates/` on host OS
- GSI_USER_DIR: path to `~/.globus` on host OS
- MYPROXY_SERVER: myproxy server (hostname:port)
- MYPROXY_USER: username for myproxy server
- GSI_PROXY_HOUR: hours for grid-proxy-init or myproxy-logon

optional parameters (default values are listed in docker-compose.yml):

- PROTOCOL: https or http
- HTTP_PORT: http port number
- HTTPS_PORT: https port number
- NEXTCLOUD_GFARM_DEBUG: debug mode (0: disable)
- http_proxy: http_proxy environment variable
- https_proxy: http_proxy environment variable
- HTTP_ACCESS_LOG: access log (1=enable)
- TZ: TZ environment variable
- NEXTCLOUD_FILES_SCAN_TIME: file scan time (crontab format)
- NEXTCLOUD_BACKUP_TIME: backup time (crontab format)
- NEXTCLOUD_TRUSTED_DOMAINS: Nextcloud parameter
- NEXTCLOUD_DEFAULT_PHONE_REGION: Nextcloud parameter
- GFARM_CHECK_ONLINE_TIME: time to check online (crontab format)
- GFARM_CREDENTIAL_EXPIRATION_THRESHOLD: minimum expiration time for Gfarm (sec.)
- GFARM_ATTR_CACHE_TIMEOUT: gfs_stat_timeout for gfarm2fs
- GFARM2FS_LOGLEVEL: loglevel for gfarmfs
- FUSE_ENTRY_TIMEOUT: entry_timeout for gfarm2fs
- FUSE_NEGATIVE_TIMEOUT: negative_timeout for gfarm2fs
- FUSE_ATTR_TIMEOUT: attr_timeout for gfarm2fs
- TRUSTED_PROXIES: reverse proxy parameter for Nextcloud
    - default: revproxy container IP address
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

## After updating configurations (.env)


```
make rebone-withlog
```

## Update Gfarm credential

To copy Gfarm shared key into container:

```
### (after updating .gfarm_shared_key)
cp ~/.gfarm_shared_key GFARM_CONF_USER_DIR/gfarm_shared_key
make copy-gfarm_shared_key
make occ-maintenancemode-off
```

To copy GSI user proxy certificate into container:

```
### (after executing grid-proxy-init or myproxy-logon on host OS)
cp /tmp/x509up_u${UID} GFARM_CONF_USER_DIR/user_proxy_cert
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
- `make logs-<container name>` for containers
    - NOTE: These are not included in the backup.
    - NOTE: These logs are removed when running `make reborn` or `make down`
- /var/log/* in Nextcloud container
    - NOTE: This is not included in the backup.

You can describe docker-compose.override.yml to change logging driver.

- https://docs.docker.com/compose/compose-file/compose-file-v3/#logging
- https://docs.docker.com/config/containers/logging/configure/

## Update to a newer Nextcloud

- run `make backup`
- change NEXTCLOUD_VERSION
- run `make reborn-withlog`

NOTE:

https://github.com/nextcloud/docker/blob/master/README.md#update-to-a-newer-version

It is only possible to upgrade one major version at a time.
For example, if you want to upgrade from version 14 to 16, you will
have to upgrade from version 14 to 15, then from 15 to 16.

## for developers

create Gfarm docker/dev environment,
and see .env-docker_dev,
and merge the file into .env,
and execute ./copy_home_files.sh to copy files into containers,
and create symlink from gfarm/docker/dev/mnt/COPY_DIR to /work/gfarm-dev
