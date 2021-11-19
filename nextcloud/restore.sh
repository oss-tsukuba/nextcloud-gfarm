#!/bin/bash

set -u
set -o pipefail
#set -x

source /config.sh

# root only
[ $(id -u) -eq 0 ] || exit 1

if [ -f "${RESTORE_FLAG_PATH}" ]; then
    echo "restore.sh is ignored (already restored)" >&2
    exit 1
fi

TMPDIR=$(mktemp --directory)

remove_tmpdir()
{
    rm -rf "${TMPDIR}"
}

finalize()
{
    remove_tmpdir
}

trap finalize EXIT

cd ${TMPDIR}

# When these files don't exist, this script fails by -e option.
${SUDO_USER} gfexport "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}" > ${SYSTEM_ARCH}
NEXTCLOUD_BACKUP_STATUS=${?}
${SUDO_USER} gfexport "${GFARM_BACKUP_PATH}/${DB_ARCH}" > ${DB_FILE}.gz
DB_BACKUP_STATUS=${?}
${SUDO_USER} gfexport "${GFARM_BACKUP_PATH}/${LOG_ARCH}" > ${LOG_ARCH}
LOG_BACKUP_STATUS=${?}

set -e

if [ ${NEXTCLOUD_BACKUP_STATUS} -eq 0 -a ${DB_BACKUP_STATUS} -eq 0 -a ${LOG_BACKUP_STATUS} -eq 0 ]; then
    tar xzpf ${SYSTEM_ARCH}
    rsync -a ${SYSTEM_DIR} /var/www

    gunzip ${DB_ARCH}
    mysql -h ${MYSQL_HOST} \
        -u root \
        -p"$(cat ${MYSQL_PASSWORD_FILE})" < ${DB_FILE}

    gunzip ${LOG_ARCH}
    mv ${LOG_FILE} "${NEXTCLOUD_LOG_PATH}"

    touch "${RESTORE_FLAG_PATH}"
fi
