#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

create_mount_point()
{
    ${SUDO_USER} mv "${DATA_DIR}" "${TMP_DATA_DIR}"
    ${SUDO_USER} mkdir -p "${DATA_DIR}"
    ${SUDO_USER} chmod 750 "${DATA_DIR}"
}

# before mount_gfarm2fs
if [ ! -d "${DATA_DIR}" ]; then
   ${SUDO_USER} mkdir -p "${DATA_DIR}"
fi
FILE_NUM=$(${SUDO_USER} ls -1a --ignore=. --ignore=.. "${DATA_DIR}" | wc -l)
if [ ${FILE_NUM} -gt 0 ]; then  # not empty
    # new container ==> initial data files exist
    create_mount_point
fi

mount_gfarm2fs

if [ ${FILE_NUM} -gt 0 ]; then  # not empty
    GFARM_DIR_FILE_NUM=$(${SUDO_USER} ls -1a --ignore=. --ignore=.. "${DATA_DIR}" | wc -l)
    if [ ${GFARM_DIR_FILE_NUM} -eq 0 ]; then
        # empty GFARM_DATA_PATH ==> copy files
        ${SUDO_USER} rsync -rlpt "${TMP_DATA_DIR}/" "${DATA_DIR}/"
    fi
    ${SUDO_USER} rm -rf "${TMP_DATA_DIR}"
fi

# initialization after creating new (or renew) container
if [ ! -f "${POST_FLAG_PATH}" ]; then
    ${OCC_USER} maintenance:mode --on || true

    # may fail
    #set +e +o pipefail
    CURRENT_LOG_PATH=`${OCC_USER} log:file | grep 'Log file:' | awk '{ print $3 }'`
    #set -e -o pipefail
    if [ "${CURRENT_LOG_PATH}" != "${NEXTCLOUD_LOG_PATH}" ]; then
        ${OCC_USER} log:file --file "${NEXTCLOUD_LOG_PATH}"
        ${SUDO_USER} mv "${CURRENT_LOG_PATH}" "${NEXTCLOUD_LOG_PATH}"
    fi

    ${OCC_USER} config:system:set skeletondirectory --value=''
    ${OCC_USER} config:system:set default_phone_region --value="${NEXTCLOUD_DEFAULT_PHONE_REGION}"

    touch "${POST_FLAG_PATH}"
fi

# backup.sh requires ${NEXTCLOUD_LOG_PATH}
touch "${NEXTCLOUD_LOG_PATH}"

# fail before initializing Nextcloud
${OCC_USER} maintenance:mode --off || true

exec "$@"
