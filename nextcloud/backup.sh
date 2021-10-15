#!/bin/bash

set -eu

source /config-env.sh
source /config.sh

# www-data only
[ $(whoami) = "www-data" ] || exit 1

if [ -f ${MYSQL_PASSWORD_FILE:-/} ];
then
    PASSWORD=`cat ${MYSQL_PASSWORD_FILE}`
else
    PASSWORD=${MYSQL_PASSWORD}
fi

TMPDIR=$(mktemp --directory)

remove_tmpdir()
{
    rm -rf "${TMPDIR}"
}

trap remove_tmpdir EXIT

cd ${TMPDIR}

php /var/www/html/occ maintenance:mode --on
fusermount -u ${DATA_DIR}

cp -pr /var/www/html ./${SYSTEM_DIR}
tar czpf ${SYSTEM_ARCH} ${SYSTEM_DIR}

mysqldump \
    -h ${MYSQL_HOST} \
    -u root \
    -p${PASSWORD} \
    -x --all-databases > ${DB_FILE}
gzip -c ${DB_FILE} > ${DB_ARCH}

gzip -c ${NEXTCLOUD_LOG_PATH} > ${LOG_ARCH}

gfarm2fs ${MNT_OPT} ${DATA_DIR}
php /var/www/html/occ maintenance:mode --off

gfmkdir -p ${GFARM_BACKUP_PATH}

gfreg ${SYSTEM_ARCH} ${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp
gfreg ${DB_ARCH} ${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp
gfreg ${LOG_ARCH} ${GFARM_BACKUP_PATH}/${LOG_ARCH}.tmp

gfmv ${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp ${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}
gfmv ${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp ${GFARM_BACKUP_PATH}/${DB_ARCH}
gfmv ${GFARM_BACKUP_PATH}/${LOG_ARCH}.tmp ${GFARM_BACKUP_PATH}/${LOG_ARCH}

gfls -l ${GFARM_BACKUP_PATH}
