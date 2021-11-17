#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -x

source /config.sh

CONFIG_ENV=/config-env.sh

MYSQL_PASSWORD_FILE_2=/var/www/nextcloud_db_password
NEXTCLOUD_ADMIN_PASSWORD_FILE_2=/var/www/nextcloud_admin_password

# for backup.sh
cat <<EOF > ${CONFIG_ENV}
### from netcloud-gfarm/nextcloud/Dockerfile
export MYSQL_DATABASE=${MYSQL_DATABASE}
export MYSQL_USER=${MYSQL_USER}
export MYSQL_PASSWORD_FILE=${MYSQL_PASSWORD_FILE_2}
export MYSQL_HOST=${MYSQL_HOST}

export NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
export NEXTCLOUD_ADMIN_PASSWORD_FILE=${NEXTCLOUD_ADMIN_PASSWORD_FILE_2}
export NEXTCLOUD_UPDATE=${NEXTCLOUD_UPDATE}
export NEXTCLOUD_LOG_PATH=${NEXTCLOUD_LOG_PATH}
export NEXTCLOUD_BACKUP_TIME="${NEXTCLOUD_BACKUP_TIME}"

export GFARM_USER=${GFARM_USER}
export GFARM_DATA_PATH=${GFARM_DATA_PATH}
export GFARM_BACKUP_PATH=${GFARM_BACKUP_PATH}
export GFARM_ATTR_CACHE_TIMEOUT=${GFARM_ATTR_CACHE_TIMEOUT}

export TZ=${TZ}

export FUSE_ENTRY_TIMEOUT=${FUSE_ENTRY_TIMEOUT}
export FUSE_NEGATIVE_TIMEOUT=${FUSE_NEGATIVE_TIMEOUT}
export FUSE_ATTR_TIMEOUT=${FUSE_ATTR_TIMEOUT}

### from nextcloud/Dockerfile
export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
export PHP_UPLOAD_LIMIT=${PHP_UPLOAD_LIMIT}
EOF

### for debug
#cat ${CONFIG_ENV}

chown0() {
    chown -R ${NEXTCLOUD_USER}:root "$@"
}

copy0() {
    src="$1"
    dst="$2"

    rm -rf "$dst"
    cp -pr "$src" "$dst"
    chmod -R go-rwx "$dst"
    chown0 "$dst"
}

copy0 "${MYSQL_PASSWORD_FILE}" "${MYSQL_PASSWORD_FILE_2}"
copy0 "${NEXTCLOUD_ADMIN_PASSWORD_FILE}" "${NEXTCLOUD_ADMIN_PASSWORD_FILE_2}"

HOMEDIR="/var/www"

GFARM_USERMAP="${HOMEDIR}/.gfarm_usermap"
echo "${GFARM_USER} ${NEXTCLOUD_USER}" > "${GFARM_USERMAP}"
chown0 "${GFARM_USERMAP}"

GFARM_SHARED_KEY="${HOMEDIR}/.gfarm_shared_key"
copy0 "/gfarm_shared_key" "${GFARM_SHARED_KEY}"

GFARM2RC="${HOMEDIR}/.gfarm2rc"
copy0 "/gfarm2rc" "${GFARM2RC}"

GFARM_CONF="/usr/local/etc/gfarm2.conf"
cp "/gfarm2.conf" "${GFARM_CONF}"
echo >> "${GFARM_CONF}"
echo "local_user_map ${GFARM_USERMAP}" >> "${GFARM_CONF}"
echo "attr_cache_timeout ${GFARM_ATTR_CACHE_TIMEOUT:-180}" >> "${GFARM_CONF}"
chown0 "${GFARM_CONF}"

DOT_GLOBUS="${HOMEDIR}/.globus"
copy0 "/dot_globus" "${DOT_GLOBUS}"

if [ -f "${GRID_PROXY_PASSWORD_FILE}" ]; then
    cat "${GRID_PROXY_PASSWORD_FILE}" | \
        ${SUDO_USER} grid-proxy-init -pwstdin -hours ${GRID_PROXY_HOURS}
    ${SUDO_USER} grid-proxy-info
fi

#TODO secret for myproxy password, MYPROXY_PASSWORD_FILE

if [ ! -f ${INIT_FLAG_PATH} ]; then
    sed -i -e 's/^NAME_COMPATIBILITY=STRICT_RFC2818$/NAME_COMPATIBILITY=HYBRID/' /etc/grid-security/gsi.conf

    mkdir -p /var/spool/cron/crontabs
    echo "${NEXTCLOUD_BACKUP_TIME:-0 3 * * *} /backup.sh" >> /var/spool/cron/crontabs/${NEXTCLOUD_USER}

    FLAG_DIR=$(dirname ${INIT_FLAG_PATH})
    mkdir -p "${FLAG_DIR}"
    chown0 "${FLAG_DIR}"
    touch "${INIT_FLAG_PATH}"
fi

# check accessibility to Gfarm
num_gfsd=$(${SUDO_USER} gfsched | wc -l)
if [ $num_gfsd -le 0 ]; then
    echo "No accessibility to Gfarm" >&2
    exit 1
fi

${SUDO_USER} gfmkdir -p ${GFARM_DATA_PATH}
${SUDO_USER} gfchmod 750 ${GFARM_DATA_PATH}

MYSQL_PASSWORD="$(cat ${MYSQL_PASSWORD_FILE})"
until mysqladmin ping -h ${MYSQL_HOST} -u ${MYSQL_USER} -p"${MYSQL_PASSWORD}"; do
    echo 'waiting for starting mysql server (${MYSQL_HOST}) ...'
    sleep 1
done

FILE_NUM=$(ls -1a --ignore=. --ignore=.. ${HOMEDIR}/html | wc -l)
if [ ${FILE_NUM} -eq 0 ]; then
    if ${SUDO_USER} gftest -d ${GFARM_BACKUP_PATH}; then
        /restore.sh
    fi
else
    touch ${VOLUME_REUSE_FLAG_PATH}
fi

# for debug
#exec bash -x "$@"
exec "$@"
