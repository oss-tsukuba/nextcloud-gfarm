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
: ${GFARM_USER}
: ${GFARM_DATA_PATH}
: ${GFARM_BACKUP_PATH}
: ${SERVER_NAME}

### optional
: ${TZ:="Asia/Tokyo"}
#### empty means disabled
: "${NEXTCLOUD_FILES_SCAN_TIME='10 5 * * *'}"
#### empty means disabled
: "${NEXTCLOUD_BACKUP_TIME='10 2 * * *'}"
#### empty means disabled, from openssl enc -list
: ${NEXTCLOUD_BACKUP_ENCRYPT="aes-256-cbc"}
: ${NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER:="10000"}
: ${NEXTCLOUD_BACKUP_USE_GFCP:="0"}
: ${NEXTCLOUD_TRUSTED_DOMAINS:=${SERVER_NAME}}
: ${NEXTCLOUD_DEFAULT_PHONE_REGION:="JP"}

#### empty means disabled
: "${GFARM_CHECK_ONLINE_TIME='*/5 * * * *'}"
: ${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD:="600"}

: ${GSI_PROXY_HOURS:="168"}
: ${MYPROXY_SERVER:=""}
: ${MYPROXY_USER:=${GFARM_USER}}

: ${GFARM_ATTR_CACHE_TIMEOUT:="60"}
: ${FUSE_ENTRY_TIMEOUT:="60"}
: ${FUSE_NEGATIVE_TIMEOUT:="5"}
: ${FUSE_ATTR_TIMEOUT:="60"}

: ${GFARM2FS_LOGLEVEL:="info"}

: ${HTTP_ACCESS_LOG:=1}

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
CONFIG_DIR="${HTML_DIR}/config"

MAIN_CONFIG="${CONFIG_DIR}/config.php"
DBPASSWORD_CONFIG="${CONFIG_DIR}/nc-gfarm-dbpassword.config.php"

TMP_DATA_DIR="${DATA_DIR}.bak"
NEXTCLOUD_LOG_PATH="${HTML_DIR}/nextcloud.log"

#GFARM2FS_DISABLE_MT="-s"
GFARM2FS_DISABLE_MT=""
MNT_OPT="${GFARM2FS_DISABLE_MT} -o loglevel=${GFARM2FS_LOGLEVEL},nonempty,modules=subdir,subdir=${GFARM_DATA_PATH},entry_timeout=${FUSE_ENTRY_TIMEOUT},negative_timeout=${FUSE_NEGATIVE_TIMEOUT},attr_timeout=${FUSE_ATTR_TIMEOUT},gfs_stat_timeout=${GFARM_ATTR_CACHE_TIMEOUT},auto_cache,big_writes"

NEXTCLOUD_USER="www-data"
NEXTCLOUD_USER_ID=$(id -u ${NEXTCLOUD_USER})

if [ $(whoami) = "${NEXTCLOUD_USER}" ]; then
    SUDO_USER=""
else
    SUDO_USER="sudo -s -E -u ${NEXTCLOUD_USER}"
fi
OCC_PATH=${HTML_DIR}/occ
OCC="${SUDO_USER} php ${OCC_PATH}"

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
MYSQL_CONF="${HOMEDIR}/nextcloud.my.cnf"
MYSQL_ROOT_SH="${HOMEDIR}/mysql_root.sh"
NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER="${HOMEDIR}/nextcloud_admin_password"

BACKUP_SH="${NCGFARM_DIR}/backup.sh"
RESTORE_SH="${NCGFARM_DIR}/restore.sh"
FILES_SCAN_SH="${NCGFARM_DIR}/files_scan.sh"

GRID_PROXY_INIT_SH="${NCGFARM_DIR}/grid-proxy-init.sh"
MYPROXY_LOGON_SH="${NCGFARM_DIR}/myproxy-logon.sh"
COPY_GFARM_SHARED_KEY_SH="${NCGFARM_DIR}/copy_gfarm_shared_key.sh"
COPY_GSI_USER_PROXY_SH="${NCGFARM_DIR}/copy_gsi_user_proxy.sh"
GFARM_CHECK_ONLINE_SH="${NCGFARM_DIR}/gfarm_check_online.sh"

##########################################################

GFARM_CONF_DIR="/gfarm_conf"
GFARM_CONF_USER_DIR="/gfarm_conf_user"

GFARM2_CONF_ORIG="${GFARM_CONF_DIR}/gfarm2.conf"
GFARM_CONF="/usr/local/etc/gfarm2.conf"

GFARM2RC_ORIG="${GFARM_CONF_USER_DIR}/gfarm2rc"
GFARM2RC="${HOMEDIR}/.gfarm2rc"

GFARM_SHARED_KEY_ORIG="${GFARM_CONF_USER_DIR}/gfarm_shared_key"
GFARM_SHARED_KEY="${HOMEDIR}/.gfarm_shared_key"

GSI_CERTIFICATES_DIR="/etc/grid-security/certificates"

GSI_USER_DIR_ORIG="/gsi_user"
GSI_USER_KEY_ORIG="/gsi_user/userkey.pem"
GSI_USER_DIR="${HOMEDIR}/.globus"
GSI_USER_KEY="${GSI_USER_DIR}/userkey.pem"

GSI_USER_PROXY_BACKUP="/gsi_proxy/user_proxy_cert"
GSI_USER_PROXY_ORIG="/${GFARM_CONF_USER_DIR}/user_proxy_cert"
GSI_USER_PROXY_PREFIX="/tmp/x509up_u"
GSI_USER_PROXY_FILE="${GSI_USER_PROXY_PREFIX}${NEXTCLOUD_USER_ID}"
