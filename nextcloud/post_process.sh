#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail
#set -x

source /nc-gfarm/config.sh

create_mount_point()
{
    mv "${DATA_DIR}" "${TMP_DATA_DIR}"
    mkdir -p "${DATA_DIR}"
    chmod 750 "${DATA_DIR}"
    chown ${NEXTCLOUD_USER}:root "${DATA_DIR}"
}

move_existing_files()
{
    ${SUDO_USER} rsync -rlpt "${TMP_DATA_DIR}/" "${DATA_DIR}/"
    rm -r "${TMP_DATA_DIR}"
}

is_mounted()
{
    df "${DATA_DIR}" | egrep -q '^gfarm2fs\s'
}

if [ ! -f "${POST_FLAG_PATH}" -a ! -f "${RESTORE_FLAG_PATH}" -a ! -f "${VOLUME_REUSE_FLAG_PATH}" -a ! -d "${DATA_DIR}" ]; then
    ${SUDO_USER} -E php /var/www/html/occ maintenance:mode --on

    CURRENT_LOG_PATH=`${SUDO_USER} -E php /var/www/html/occ log:file | grep 'Log file:' | awk '{ print $3 }'`
    if [ "${CURRENT_LOG_PATH}" != "${NEXTCLOUD_LOG_PATH}" ]; then
        ${SUDO_USER} -E php /var/www/html/occ log:file --file "${NEXTCLOUD_LOG_PATH}"
        mv "${CURRENT_LOG_PATH}" "${NEXTCLOUD_LOG_PATH}"
    fi
    ${SUDO_USER} -E php /var/www/html/occ config:system:set skeletondirectory --value=''

    create_mount_point

    ${SUDO_USER} gfarm2fs ${MNT_OPT} "${DATA_DIR}"

    move_existing_files

    touch "${POST_FLAG_PATH}"
fi

if ! is_mounted; then
    FILE_NUM=$(ls -1a --ignore=. --ignore=.. "${DATA_DIR}" | wc -l)
    if [ ${FILE_NUM} -gt 0 ]; then
        create_mount_point
    fi

    ${SUDO_USER} gfarm2fs ${MNT_OPT} "${DATA_DIR}"

    if [ ${FILE_NUM} -gt 0 ]; then
        move_existing_files
    fi
fi

# backup.sh requires ${NEXTCLOUD_LOG_PATH}
touch "${NEXTCLOUD_LOG_PATH}"

# fail before initializing Nextcloud.
${SUDO_USER} -E php /var/www/html/occ maintenance:mode --off || true

exec "$@"
