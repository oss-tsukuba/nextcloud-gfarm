#!/bin/bash

set -eu

source /config.sh

if [ ! -f ${INIT_FLAG_PATH} ];
then
    cp /gfarm2rc /var/www/.gfarm2rc
    chown ${NEXTCLOUD_USER}:root /var/www/.gfarm2rc

    echo "${GFARM_USER} ${NEXTCLOUD_USER}" > /var/www/.gfarm_map
    chown ${NEXTCLOUD_USER}:root /var/www/.gfarm_map

    cp /gfarm_shared_key /var/www/.gfarm_shared_key
    chmod 600 /var/www/.gfarm_shared_key
    chown ${NEXTCLOUD_USER}:root /var/www/.gfarm_shared_key

    cp /gfarm2.conf /usr/local/etc
    echo "" >> /usr/local/etc/gfarm2.conf
    echo "local_user_map /var/www/.gfarm_map" >> /usr/local/etc/gfarm2.conf
    chown ${NEXTCLOUD_USER}:root /usr/local/etc/gfarm2.conf

    ${SUDO} gfsudo gfchmod 770 ${GFARM_DATA_PATH}

    mkdir -p /var/spool/cron/crontabs
    echo "${NEXTCLOUD_BACKUP_TIME:-0 3 * * *} /backup.sh" >> /var/spool/cron/crontabs/${NEXTCLOUD_USER}

    mkdir -p ${NEXTCLOUD_SPOOL_PATH}
    chown ${NEXTCLOUD_USER}:root ${NEXTCLOUD_SPOOL_PATH}
    touch ${INIT_FLAG_PATH}
fi

FILE_NUM=`ls -1a --ignore=. --ignore=.. /var/www/html | wc -l `
if [ ${FILE_NUM} -eq 0 ];
then
    ${SUDO} gfls ${GFARM_BACKUP_PATH}
    if [ ${?} -eq 0 ];
    then
        /restore.sh
    fi
else
    touch ${VOLUME_REUSE_FLAG_PATH}
fi

exec "$@"
