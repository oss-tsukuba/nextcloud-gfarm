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

- [Docker Engine and Docker Compose](https://docs.docker.com/engine/install/)
    - (Docker Desktop is not required.)
- Gfarm configuration file (gfarm2.conf)
    - There is no need to install Gfarm on the host OS.
- GNU make
    - All applications will be build in container.
- /bin/bash
- openssl command
- curl command

Optional:

- Gfarm user configuration (~/.gfarm2rc)
- Gfarm shared key (~/.gfarm_shared_key)
- GSI user key (~/.globus/usercert.pem + ~/.globus/userkey.pem + pass-phrase)
- GSI user proxy certificate (`/tmp/x509up_u<UID>`)
- GSI myproxy server (hostname + password)

## Quick start

- install Docker and Docker Compose
- run `make init` to configure parameters and create `config.env`.
  (or run `make init-hpci` for HPCI shared storage.)
    - `KEY [DEFAULT]: <your input to set VALUE>`
        - for KEY and VALUE, see details below
    - input a password file for Nextcloud admin.
        - Don't forget `./secrets/nextcloud_admin_password`
        - The password is for restoring from backup,
          and for Nextcloud login as admin user.
    - create a password file for MariaDB automatically.
        - check `./secrets/db_password`
        - (used by Nextcloud to connect MariaDB)
    - create symlink of `docker-compose.override.yml` automatically.
        - PROTOCOL=https : for `docker-compose.override.yml.https`
        - PROTOCOL=http  : for `docker-compose.override.yml.http`
- edit `config.env` for further changes. (see details below)
    - correct and add parameters.
- check and edit `docker-compose.override.yml`
    - If you do not need symlink of `docker-compose.override.yml`, remove it.
    - use one of other `docker-compose.override.yml.*`
    - or write new `docker-compose.override.yml` for your environment
- run `make check-config` to check configurations.
- run `make selfsigned-cert-generate` to activate HTTPS when using HTTPS.
- run `make reborn` to create and start containers.
    - If containers exist, these will be recreated.
    - Persistent data (DB, coniguration files, and etc.) is not removed.
- input password of myproxy-logon or grid-proxy-init for Gfarm
  authentication method (when not using .gfarm_shared_key)
- copy certificate files for HTTPS to `nextcloud-gfarm-revproxy-1:/etc/nginx/certs` volume when using HTTPS and not using selfsigned certificate.
    - NOTE: HTTPS port is disabled when certificate files do not exist.
    - prepare the following files
        - ${SERVER_NAME}.key (SSL_KEY)
        - ${SERVER_NAME}.csr (SSL_CSR)
        - ${SERVER_NAME}.crt (SSL_CERT)
        - and run `sudo docker cp <filename> nextcloud-gfarm-revproxy-1:/etc/nginx/certs/<filename>` to copy a file
        - and run `make restart@revproxy`
    - or run `make selfsigned-cert-generate` to generate and copy self-signed certificate
        - and run `make selfsigned-cert-fingerprint` to show fingerprint
    - or (unsurveyed:) write new docker-compose.override.yml and use acme-companion for nginx-proxy to use Let's Encrypt certificate
        - https://github.com/nginx-proxy/acme-companion
        - https://github.com/nginx-proxy/acme-companion/blob/main/docs/Docker-Compose.md
        - https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/mariadb/fpm/docker-compose.yml
    - or etc.
- run `make restart@revproxy` after certificate files for HTTPS are updated.
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

### Configuration format

```
KEY=VALUE
```

For details of Nextcloud parameters, please refer to
[nextcloud/docker](https://hub.docker.com/_/nextcloud/).

### Mandatory parameters
- NEXTCLOUD_VERSION: Nextcloud version
- SERVER_NAME: server name for this Nextcloud
- PROTOCOL: https or http
- GFARM_USER: Gfarm user name
- GFARM_DATA_PATH: Gfarm data directory
    - NOTE: Do not share GFARM_DATA_PATH with other nextcloud-gfarm.
- GFARM_BACKUP_PATH: Gfarm backup directory
    - NOTE: Do not share GFARM_BACKUP_PATH with other nextcloud-gfarm.
- GFARM_CONF_DIR: path to parent directory on host OS for the following files
     - gfarm2.conf: Gfarm configuration file

### Required parameters when using http
- PROTOCOL: `http` is required
- HTTP_PORT: http port

### Required parameters when using https
- PROTOCOL: `https` is required
- HTTP_PORT: http port (redirect to https port)
- HTTPS_PORT: https port

### Gfarm parameters
Default is specified by `docker-compose.yml`.
- GFARM_CONF_USER_DIR: path to parent directory on host OS for the following files (Please make a special directory and copy the files)
    - `gfarm2rc` (optional) (copy from `~/.gfarm2rc`)
    - `gfarm_shared_key` (optional) (copy from `~/.gfarm_shared_key`)
    - `user_proxy_cert` (optional) (copy from `/tmp/x509up_u<UID>`)
- GSI_USER_DIR: path to `~/.globus` on host OS
- MYPROXY_SERVER: myproxy server (hostname:port) (optional)
- MYPROXY_USER: username for myproxy server (when using MYPROXY_SERVER)

### Optional parameters
Default is specified by `docker-compose.yml`.
- GSI_PROXY_HOUR: expiration hours of the certificate for grid-proxy-init or myproxy-logon
- GSI_CERTIFICATES_DIR: a directory for public keys for trusted certificate authorities on the host OS
- NEXTCLOUD_GFARM_DEBUG: debug mode (0: disable)
- http_proxy: http_proxy environment variable
- https_proxy: http_proxy environment variable
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

```
make stop
```

start:

```
make restart-withlog
### `ctrl-c` to stop log messages
```

## After updating configurations (config.env)

```
make reborn
```

or

```
make reborn-withlog
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

Nextcloud database will be automatically backed up to Gfarm filesystem
according to NEXTCLOUD_BACKUP_TIME.

To back up Nextcloud database manually:

- run `make backup`

To back up configuration files.

- copy `./secrets/*` files and `config.env` to a safe place.

NOTE: `./secrets/nextcloud_admin_password` is also used to encrypt the backup data.  So the same password is required when restoring.  However, `./secrets/nextcloud_admin_password` is not backed up by this function.

## Restore

Even if Nextcloud database is broken or lost, you can restore from backup:

- run `make down-REMOVE_VOLUMES`
    - WARNING: Local database will be removed.
- deploy `./secrets/*` files and `config.env`
- edit `config.env` and set `NEXTCLOUD_UPDATE=0`
- run `make reborn`

## Logging

- Nextcloud log: Nextcloud UI -> Logging
    - or /var/www/html/nextcloud.log in container.
    - This is included in the backup.

- /var/log/* in Nextcloud container
    - NOTE: This is not included in the backup.

- run `make logs` to show log of nextcloud (main container)
- run `make logs@<container name>` to show log of the other containr
- run `make logs-follow` or `make logs-follow@<container name>` to follow log
    - NOTE: These are not included in the backup.
    - NOTE: These logs are removed when running `make reborn` or `make down`

You can describe docker-compose.override.yml to change logging driver.

- https://docs.docker.com/compose/compose-file/compose-file-v3/#logging
- https://docs.docker.com/config/containers/logging/configure/

## Update containers

- update nextcloud-gfarm source
- or update `config.env`
- or update docker-compose.yml
- or run `make build-nocache` to update packages forcibly
- and run `make reborn`

## Upgrade to a newer Nextcloud

- run `make backup`
- edit `config.env`
    - set `NEXTCLOUD_UPDATE=1`
    - increase `NEXTCLOUD_VERSION` by exactly 1 more than current major version
       - run `show-nextcloud-version` to show current version
- run `make reborn`

SEE ALSO:

https://github.com/nextcloud/docker/blob/master/README.md#update-to-a-newer-version

It is only possible to upgrade one major version at a time.
For example, if you want to upgrade from version 14 to 16, you will
have to upgrade from version 14 to 15, then from 15 to 16.

NOTE: Downgrading is not supported.

For example, if the following error occurred, set `NEXTCLOUD_VERSION=22` in `config.env`.

```
nextcloud_1  | Can't start Nextcloud because the version of the data (23.0.1.2) is higher than the docker image version (22.2.5.1) and downgrading is not supported. Are you sure you have pulled the newest image version?
nextcloud-gfarm_nextcloud_1 exited with code 1
```

NOTE: If the upgrade fails:

Undo NEXTCLOUD_VERSION and see `Restore` section.


## Change DB password

- run `make backup`
- run `make down-REMOVE_VOLUMES`
    - clear password for root user of mariadb
- edit `./secrets/db_password`
- run `make reborn`
    - set new password for root user of mariadb in mariadb container
    - set new password for nextcloud user of mariadb in nextcloud container

NOTE: Password for root user and nextcloud user of mariadb is the same.

NOTE: Nextcloud may not have official instructions on how to change the password.  Therefore, nextcloud-gfarm has implemented the change process for the password in `./nextcloud/entrypoint0.sh`.

## Reset Nextcloud admin password

- run `make resetpassword-admin`
- input a new password.
    - `./secrets/nextcloud_admin_password` will be updated.
    - The Password in DB will also be updated.
- run `make reborn` to reflect the password file in container.
- run `make backup` to change the password for backup data.

SEE ALSO:

https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/reset_admin_password.html


## For developers

- create Gfarm docker/dev environment
- and run `ln -s <path to gfarm/docker/dev/mnt/COPY_DIR> /work/gfarm-dev`
- and run `make init-dev`
- and run `./copy_home_files.sh` to copy files into containers
- or create `template-orverride.env` for your environment
