#!/bin/bash

set -eu
set -o pipefail
#set -x

source /config-env.sh
source /config.sh

BACKUP_FLAG="${NEXTCLOUD_SPOOL_PATH}/backup"

# www-data only
[ $(whoami) = "${NEXTCLOUD_USER}" ] || exit 1

if [ -f ${MYSQL_PASSWORD_FILE:-/} ]; then
    PASSWORD="$(cat ${MYSQL_PASSWORD_FILE})"
else
    PASSWORD="${MYSQL_PASSWORD}"
fi

TMPDIR="$(mktemp --directory)"

mount_gfarm()
{
    gfarm2fs ${MNT_OPT} "${DATA_DIR}"
}

maintenance_mode_off()
{
    php /var/www/html/occ maintenance:mode --off
}

remove_tmpdir()
{
    rm -f "${BACKUP_FLAG}"
    rm -rf "${TMPDIR}"
}

FUSEMOUNT=1
MAINTENACE=0

mount_and_start()
{
    if [ ${FUSEMOUNT} -eq 0 ]; then
        mount_gfarm
        FUSEMOUNT=1
    fi
    if [ ${MAINTENACE} -eq 1 ]; then
        maintenance_mode_off
        MAINTENACE=0
    fi
}

reset_on_error()
{
    mount_and_start
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT

umount_retry()
{
    while ! fusermount -u "${DATA_DIR}"; do
        echo "retrying umount..."
        sleep 1
    done
}

if [ -f "${BACKUP_FLAG}" ]; then
    echo "another backup.sh is running" >&2
    exit 1
fi
touch "${BACKUP_FLAG}"

cd "${TMPDIR}"

php /var/www/html/occ maintenance:mode --on
MAINTENACE=1

umount_retry
FUSEMOUNT=0

cp -pr /var/www/html ./${SYSTEM_DIR}
tar czpf ${SYSTEM_ARCH} ${SYSTEM_DIR}

mysqldump \
    -h ${MYSQL_HOST} \
    -u root \
    -p"${PASSWORD}" \
    -x --all-databases > ${DB_FILE}
gzip -c ${DB_FILE} > ${DB_ARCH}

gzip -c "${NEXTCLOUD_LOG_PATH}" > ${LOG_ARCH}

mount_and_start

gfmkdir -p "${GFARM_BACKUP_PATH}"

gfreg ${SYSTEM_ARCH} "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp"
gfreg ${DB_ARCH} "${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp"
gfreg ${LOG_ARCH} "${GFARM_BACKUP_PATH}/${LOG_ARCH}.tmp"

gfchmod 600 "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${LOG_ARCH}.tmp"

gfmv "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}"
gfmv "${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${DB_ARCH}"
gfmv "${GFARM_BACKUP_PATH}/${LOG_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${LOG_ARCH}"

gfls -l "${GFARM_BACKUP_PATH}"
echo "Backup is complete."
