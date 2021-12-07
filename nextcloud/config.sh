#!/bin/bash

NEXTCLOUD_USER=www-data
HOMEDIR="/var/www"
SUDO_USER="sudo -s -u ${NEXTCLOUD_USER}"
DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/www/html/data}"
TMP_DATA_DIR="${DATA_DIR}.bak"
MNT_OPT="-o nonempty,modules=subdir,subdir=${GFARM_DATA_PATH},entry_timeout=${FUSE_ENTRY_TIMEOUT},negative_timeout=${FUSE_NEGATIVE_TIMEOUT},attr_timeout=${FUSE_ATTR_TIMEOUT},auto_cache,big_writes"

SYSTEM_DIR=html
SYSTEM_ARCH=${SYSTEM_DIR}.tar.gz
DB_FILE=dbdump.mysql
DB_ARCH=${DB_FILE}.gz
LOG_FILE=nextcloud.log
LOG_ARCH=${LOG_FILE}.gz

NEXTCLOUD_SPOOL_PATH="/var/spool/nextcloud"
INIT_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/init"
VOLUME_REUSE_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/reuse"
RESTORE_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/restore"
POST_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/post"

GFARM_SHARED_KEY_ORIG="/gfarm_shared_key"
GFARM_SHARED_KEY="${HOMEDIR}/.gfarm_shared_key"
