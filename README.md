# nextcloud-gfarm

## Overview

- Nextcloud container with Gfarm as back-end storage.
- Use one Gfarm user and the data directory for multiple Nextcloud users.
    - Mapping of Gfarm user and Nextcloud user is not supported.
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
- run `make init` to configure parameters and create `config.env`,
  (or run `make init-hpci` for HPCI shared storage.)
    - `KEY [DEFAULT]: <your input to set VALUE>`
        - for KEY and VALUE, see details below
    - create a password file for MariaDB automatically.
        - check `./secrets/db_password`
        - (used by Nextcloud to connect MariaDB)
    - create a password file for Nextcloud admin automatically.
        - check `./secrets/nextcloud_admin_password`
        - (to be entered at the Nextcloud login screen for admin user)
    - create symlink of `docker-compose.override.yml` automatically.
        - PROTOCOL=https : use `docker-compose.override.yml.https`
        - PROTOCOL=http  : use `docker-compose.override.yml.http`
- edit `config.env` for further changes. (see details below)
    - correct and add parameters.
- check and edit `docker-compose.override.yml`
    - use one of other `docker-compose.override.yml.*`
    - or write new `docker-compose.override.yml` for your environment
- run `make config` to check configurations.
- run `make reborn-withlog`
- input password of myproxy-logon or grid-proxy-init for Gfarm
  authentication method (when not using .gfarm_shared_key)
- `ctrl-c` to stop output of `make reborn-withlog`
- copy certificate files for HTTPS to `nextcloud-gfarm-revproxy-1:/etc/nginx/certs` volume when using docker-compose.override.yml.https
    - NOTE: HTTPS port is disabled when certificate files do not exist.
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
    - password: `<value of ./secrets/nextcloud_admin_password>`

## HTTPS (SSL/TLS) and Certificates and Reverse proxy

Please refer to
[Make your Nextcloud available from the internet](https://github.com/nextcloud/docker/blob/master/README.md#make-your-nextcloud-available-from-the-internet)

docker-compose.override.yml.https is an example to setup
using a reverse proxy and using self signed certificates.

You can use other reverse proxy and describe
docker-compose.override.yml for the environment.

## Configuration file (config.env)

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
- GFARM_CONF_DIR: path to parent directory on host OS for the following files
     - gfarm2.conf: Gfarm configuration file

Gfarm parameters (if necessary)
(default values are listed in docker-compose.yml):

- GFARM_CONF_USER_DIR: path to parent directory on host OS for the following files (Please make a special directory and copy the files)
    - `gfarm2rc` (optional) (copy from `~/.gfarm2rc`)
    - `gfarm_shared_key` (optional) (copy from `~/.gfarm_shared_key`)
    - `user_proxy_cert` (optional) (copy from `/tmp/x509up_u<UID>`)
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

## Stop and Start

stop:

```
make stop
```

start:

```
make restart-withlog
```

## After updating configurations (config.env)


```
make rebone-withlog
```

## Synchronize files from Gfarm

```
make files-scan
```

NOTE: This is ran automatically by NEXTCLOUD_FILES_SCAN_TIME.

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

NOTE: `./secrets/nextcloud_admin_password` is also used to encrypt the backup data.  So the same password is required when restoring.

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

## Update containers

- update nextcloud-gfarm source
- or update config.env
- or update docker-compose.yml
- or run `make build-nocache` to update packages forcibly
- and run `make reborn-withlog`

## Update to a newer Nextcloud

- run `make backup`
- change NEXTCLOUD_VERSION
- run `make reborn-withlog`

SEE ALSO:

https://github.com/nextcloud/docker/blob/master/README.md#update-to-a-newer-version

It is only possible to upgrade one major version at a time.
For example, if you want to upgrade from version 14 to 16, you will
have to upgrade from version 14 to 15, then from 15 to 16.

## Change DB password

- run `make backup`
- run `make down-REMOVE_VOLUMES`
    - clear password for root user of mariadb
- edit `./secrets/db_password`
- run `make reborn-withlog`
    - set new password for root user of mariadb in mariadb container
    - set new password for nextcloud user of mariadb in nextcloud container

NOTE: Password for root user and nextcloud user of mariadb is the same.

NOTE: Nextcloud may not have official instructions on how to change the password.  Therefore, nextcloud-gfarm has implemented the change process for the password in `./nextcloud/entrypoint0.sh`.

## Reset Nextcloud admin password

- run `make resetpassword-admin`
- edit `./secrets/nextcloud_admin_password` and set the same password.
- run `make backup` to change the password for backup data.

SEE ALSO:

https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/reset_admin_password.html


## For developers

- create Gfarm docker/dev environment
- and run `ln -s <path to gfarm/docker/dev/mnt/COPY_DIR> /work/gfarm-dev`
- and run `make init-dev`
- and run `./copy_home_files.sh` to copy files into containers

- or create `template-orverride.env` for your environment
