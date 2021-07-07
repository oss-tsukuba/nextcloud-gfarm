#!/bin/bash

set -eu

source /config.sh

function create_mount_point() {
    mv ${DATA_DIR} ${TMP_DATA_DIR}
    mkdir -p ${DATA_DIR}
    chmod 770 ${DATA_DIR}
    chown ${NEXTCLOUD_USER}:root ${DATA_DIR}
}

function move_existing_files() {
    ${SUDO} rsync -rlpt ${TMP_DATA_DIR}/ ${DATA_DIR}/
    rm -r ${TMP_DATA_DIR}
}

if [ ! -f ${POST_FLAG_PATH} -a ! -f ${VOLUME_REUSE_FLAG_PATH} ];
then
    ${SUDO} -E php /var/www/html/occ maintenance:mode --on

    CURRENT_LOG_PATH=`${SUDO} -E php /var/www/html/occ log:file | grep 'Log file:' | awk '{ print $3 }'`
    if [ "${CURRENT_LOG_PATH}" != "${NEXTCLOUD_LOG_PATH}" ];
    then
        ${SUDO} -E php /var/www/html/occ log:file --file ${NEXTCLOUD_LOG_PATH}
        mv ${CURRENT_LOG_PATH} ${NEXTCLOUD_LOG_PATH}
    fi

    create_mount_point

    ${SUDO} gfarm2fs ${MNT_OPT} ${DATA_DIR}

    move_existing_files

    ${SUDO} -E php /var/www/html/occ maintenance:mode --off
    touch ${POST_FLAG_PATH}
fi

MOUNT_POINT=`mount | grep fuse.gfarm2fs | wc -l`
if [ ${MOUNT_POINT} -eq 0 ];
then
    FILE_NUM=`ls -1a --ignore=. --ignore=.. ${DATA_DIR} | wc -l `
    if [ ${FILE_NUM} -gt 0 ];
    then
        create_mount_point
    fi

    ${SUDO} gfarm2fs ${MNT_OPT} ${DATA_DIR}

    if [ ${FILE_NUM} -gt 0 ];
    then
        move_existing_files
    fi
fi

exec "$@"
