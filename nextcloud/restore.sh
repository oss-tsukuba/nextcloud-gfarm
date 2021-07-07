#!/bin/bash

set -u

source /config.sh

cd /tmp
rm -rf ${SYSTEM_ARCH} ${DB_ARCH} ${LOG_ARCH} ${DB_FILE} ${SYSTEM_DIR}

# When these files don't exist, this script fails by -e option.
${SUDO} gfexport ${GFARM_BACKUP_PATH}/${SYSTEM_ARCH} > ${SYSTEM_ARCH}
NEXTCLOUD_BACKUP_STATUS=${?}
${SUDO} gfexport ${GFARM_BACKUP_PATH}/${DB_ARCH} > ${DB_FILE}.gz
DB_BACKUP_STATUS=${?}
${SUDO} gfexport ${GFARM_BACKUP_PATH}/${LOG_ARCH} > ${LOG_ARCH}
LOG_BACKUP_STATUS=${?}

set -e

if [ ${NEXTCLOUD_BACKUP_STATUS} -eq 0 -a ${DB_BACKUP_STATUS} -eq 0 -a ${LOG_BACKUP_STATUS} -eq 0 ];
then
    tar xzpf ${SYSTEM_ARCH}
    rsync -a ${SYSTEM_DIR} /var/www

    gunzip ${DB_ARCH}
    mysql -h ${MYSQL_HOST} \
        -u root \
        -p`cat ${MYSQL_PASSWORD_FILE}` < ${DB_FILE}

    DATA_DIR=${NEXTCLOUD_DATA_DIR:-/var/www/html/data}
    MNT_OPT="-o modules=subdir,subdir=${GFARM_DATA_PATH:-/}"
    ${SUDO} gfarm2fs ${MNT_OPT} ${DATA_DIR}
    ${SUDO} -E php /var/www/html/occ maintenance:mode --off

    ${SUDO} fusermount -u ${DATA_DIR}

    gunzip ${LOG_ARCH}
    mv ${LOG_FILE} ${NEXTCLOUD_LOG_PATH}

    touch ${RESTORE_FLAG_PATH}
fi

rm -rf ${SYSTEM_ARCH} ${DB_ARCH} ${LOG_ARCH} ${DB_FILE} ${SYSTEM_DIR}
