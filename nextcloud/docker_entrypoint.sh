#!/bin/bash

set -eu
set -x

source /config.sh

CONFIG_ENV=/config-env.sh

MYSQL_PASSWORD_FILE_2=/var/www/nextcloud_db_password
NEXTCLOUD_ADMIN_PASSWORD_FILE_2=/var/www/nextcloud_admin_password

cp ${MYSQL_PASSWORD_FILE} ${MYSQL_PASSWORD_FILE_2}
cp ${NEXTCLOUD_ADMIN_PASSWORD_FILE} ${NEXTCLOUD_ADMIN_PASSWORD_FILE_2}
chown www-data ${MYSQL_PASSWORD_FILE_2} ${NEXTCLOUD_ADMIN_PASSWORD_FILE_2}
chmod 600 ${MYSQL_PASSWORD_FILE_2} ${NEXTCLOUD_ADMIN_PASSWORD_FILE_2}

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

cat ${CONFIG_ENV}

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
    set +e
    RESULT=`grep attr_cache_timeout /usr/local/etc/gfarm2.conf`
    set -e
    if [ ${RESULT:-1} -eq 1 ];
    then
        echo "attr_cache_timeout ${GFARM_ATTR_CACHE_TIMEOUT:-180}" >> /usr/local/etc/gfarm2.conf
    fi
    chown ${NEXTCLOUD_USER}:root /usr/local/etc/gfarm2.conf

    ${SUDO_USER} gfmkdir -p ${GFARM_DATA_PATH}
    #${SUDO_USER} gfchown ${GFARM_USER}:gfarmadm ${GFARM_DATA_PATH}
    ${SUDO_USER} gfchmod 770 ${GFARM_DATA_PATH}

    mkdir -p /var/spool/cron/crontabs
    echo "${NEXTCLOUD_BACKUP_TIME:-0 3 * * *} /backup.sh" >> /var/spool/cron/crontabs/${NEXTCLOUD_USER}

    mkdir -p ${NEXTCLOUD_SPOOL_PATH}
    chown ${NEXTCLOUD_USER}:root ${NEXTCLOUD_SPOOL_PATH}
    touch ${INIT_FLAG_PATH}
fi

MYSQL_PASSWORD=$(cat ${MYSQL_PASSWORD_FILE})
until mysqladmin ping -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}; do
    echo 'waiting for starting mysql server (${MYSQL_HOST}) ...'
    sleep 1
done

FILE_NUM=`ls -1a --ignore=. --ignore=.. /var/www/html | wc -l `
if [ ${FILE_NUM} -eq 0 ];
then
    if ${SUDO_USER} gftest -d ${GFARM_BACKUP_PATH};
    then
        /restore.sh
    fi
else
    touch ${VOLUME_REUSE_FLAG_PATH}
fi

# for debug
#exec bash -x "$@"
exec "$@"
