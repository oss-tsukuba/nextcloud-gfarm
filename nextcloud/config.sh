#!/bin/bash

NCGFARM_DIR="/nc-gfarm"
CONFIG_LIB="${NCGFARM_DIR}/common-lib.sh"
CONFIG_ENV="${NCGFARM_DIR}/config-env.sh"

if [ ${NEXTCLOUD_GFARM_DEBUG:-0} -ne 0 ]; then
    set -x
fi

if [ -f "$CONFIG_ENV" ]; then
    source "$CONFIG_ENV"
fi

##########################################################

# overridable in docker-compose.yml

### mandatory
GFARM_USER=${GFARM_USER}
GFARM_DATA_PATH=${GFARM_DATA_PATH}
GFARM_BACKUP_PATH=${GFARM_BACKUP_PATH}
VIRTUAL_HOST=${VIRTUAL_HOST}

### optional
TZ=${TZ:-"Asia/Tokyo"}

NEXTCLOUD_FILES_SCAN_TIME=${NEXTCLOUD_FILES_SCAN_TIME:-'40 */3 * * *'}
NEXTCLOUD_BACKUP_TIME=${NEXTCLOUD_BACKUP_TIME:-'0 3 * * *'}
NEXTCLOUD_TRUSTED_DOMAINS=${NEXTCLOUD_TRUSTED_DOMAINS:-${VIRTUAL_HOST}}
NEXTCLOUD_DEFAULT_PHONE_REGION=${NEXTCLOUD_DEFAULT_PHONE_REGION:-"JP"}

GFARM_CHECK_ONLINE_TIME=${GFARM_CHECK_ONLINE_TIME:-'*/5 * * * *'}
GFARM_CREDENTIAL_EXPIRATION_THRESHOLD=${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD:-600}

GRID_PROXY_HOURS=${GRID_PROXY_HOURS:-"168"}
MYPROXY_SERVER=${MYPROXY_SERVER:-""}
MYPROXY_USER=${MYPROXY_USER:-${GFARM_USER}}

GFARM_ATTR_CACHE_TIMEOUT=${GFARM_ATTR_CACHE_TIMEOUT:-"180"}
FUSE_ENTRY_TIMEOUT=${FUSE_ENTRY_TIMEOUT:-"180"}
FUSE_NEGATIVE_TIMEOUT=${FUSE_NEGATIVE_TIMEOUT:-"5"}
FUSE_ATTR_TIMEOUT=${FUSE_ATTR_TIMEOUT:-"180"}

##########################################################

MYSQL_DATABASE="nextcloud"
MYSQL_USER="nextcloud"
MYSQL_PASSWORD_FILE="/run/secrets/db_password"
MYSQL_HOST="mariadb"

NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PASSWORD_FILE="/run/secrets/nextcloud_admin_password"

MYPROXY_PASSWORD_FILE="/run/secrets/myproxy_password"
GRID_PROXY_PASSWORD_FILE="/run/secrets/grid_proxy_password"

##########################################################

HOMEDIR="/var/www"
HTML_DIR="${HOMEDIR}/html"
DATA_DIR="${HTML_DIR}/data"
TMP_DATA_DIR="${DATA_DIR}.bak"
NEXTCLOUD_LOG_PATH="${HTML_DIR}/nextcloud.log"

MNT_OPT="-o nonempty,modules=subdir,subdir=${GFARM_DATA_PATH},entry_timeout=${FUSE_ENTRY_TIMEOUT},negative_timeout=${FUSE_NEGATIVE_TIMEOUT},attr_timeout=${FUSE_ATTR_TIMEOUT},gfs_stat_timeout=${GFARM_ATTR_CACHE_TIMEOUT},auto_cache,big_writes"

NEXTCLOUD_USER="www-data"

if [ $(whoami) = "${NEXTCLOUD_USER}" ]; then
    SUDO_USER=""
else
    SUDO_USER="sudo -s -E -u ${NEXTCLOUD_USER}"
fi
OCC="${SUDO_USER} php ${HTML_DIR}/occ"

CRONTAB_TEMPLATE="${NCGFARM_DIR}/crontab.tmpl"
CRONTAB_DIR_PATH="/var/spool/cron/crontabs"
CRONTAB_FILE_PATH="${CRONTAB_DIR_PATH}/${NEXTCLOUD_USER}"

GFARM_CRED_STATUS_FILE="/tmp/nextcloud-gfarm-cred_status"
GFARM_CHECK_ACCESS_FILE="${DATA_DIR}/.nextcloud-gfarm-accesstime"

SYSTEM_DIR_NAME="html"
SYSTEM_ARCH="${SYSTEM_DIR_NAME}.tar.gz"
DB_FILE_NAME="dbdump.mysql"
DB_ARCH="${DB_FILE_NAME}.gz"

NEXTCLOUD_SPOOL_PATH="/var/spool/nextcloud"
INIT_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/init"
VOLUME_REUSE_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/reuse"
RESTORE_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/restore"
POST_FLAG_PATH="${NEXTCLOUD_SPOOL_PATH}/post"

MYSQL_PASSWORD_FILE_FOR_USER="${HOMEDIR}/nextcloud_db_password"
NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER="${HOMEDIR}/nextcloud_admin_password"

GFARM_SHARED_KEY_ORIG="/gfarm_shared_key"
GFARM_SHARED_KEY="${HOMEDIR}/.gfarm_shared_key"

GLOBUS_USER_DIR_ORIG="/dot_globus"
GLOBUS_USER_DIR="${HOMEDIR}/.globus"
GLOBUS_USER_KEY="${GLOBUS_USER_DIR}/userkey.pem"

GLOBUS_USER_PROXY_ORIG="/globus_user_proxy"
GLOBUS_USER_PROXY_PREFIX="/tmp/x509up_u"

BACKUP_SH="${NCGFARM_DIR}/backup.sh"
RESTORE_SH="${NCGFARM_DIR}/restore.sh"
FILES_SCAN_SH="${NCGFARM_DIR}/files_scan.sh"

GRID_PROXY_INIT_SH="${NCGFARM_DIR}/grid-proxy-init.sh"
MYPROXY_LOGON_SH="${NCGFARM_DIR}/myproxy-logon.sh"
COPY_GFARM_SHARED_KEY_SH="${NCGFARM_DIR}/copy_gfarm_shared_key.sh"
COPY_GLOBUS_USER_PROXY_SH="${NCGFARM_DIR}/copy_globus_user_proxy.sh"
GFARM_CHECK_ONLINE_SH="${NCGFARM_DIR}/gfarm_check_online.sh"
