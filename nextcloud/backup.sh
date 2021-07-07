#!/bin/bash

set -eu

source /config.sh

if [ -f ${MYSQL_PASSWORD_FILE:-/} ];
then
    PASSWORD=`cat ${MYSQL_PASSWORD_FILE}`
else 
    PASSWORD=${MYSQL_PASSWORD}
fi

php /var/www/html/occ maintenance:mode --on
fusermount -u ${DATA_DIR}

cd /tmp
rm -rf ${SYSTEM_ARCH} ${DB_ARCH} ${LOG_ARCH} ${DB_FILE} ${SYSTEM_DIR}

cp -r /var/www/html .
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
gfreg ${SYSTEM_ARCH} ${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}
gfreg ${DB_ARCH} ${GFARM_BACKUP_PATH}/${DB_ARCH}
gfreg ${LOG_ARCH} ${GFARM_BACKUP_PATH}/${LOG_ARCH}
gfls -l ${GFARM_BACKUP_PATH}

rm -rf ${SYSTEM_ARCH} ${DB_ARCH} ${LOG_ARCH} ${DB_FILE} ${SYSTEM_DIR}
