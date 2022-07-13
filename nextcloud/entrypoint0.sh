#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

export OVERWRITEHOST
export OVERWRITEPROTOCOL

cat <<EOF > "${CONFIG_ENV}"
### from /nc-gfarm/config.sh
export MYSQL_DATABASE=${MYSQL_DATABASE}
export MYSQL_USER=${MYSQL_USER}
export MYSQL_PASSWORD_FILE="${MYSQL_PASSWORD_FILE}"
export MYSQL_PASSWORD_FILE_FOR_USER="${MYSQL_PASSWORD_FILE_FOR_USER}"
export MYSQL_HOST=${MYSQL_HOST}

export NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
export NEXTCLOUD_ADMIN_PASSWORD_FILE="${NEXTCLOUD_ADMIN_PASSWORD_FILE}"
export NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER="${NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER}"
export NEXTCLOUD_LOG_PATH="${NEXTCLOUD_LOG_PATH}"
export NEXTCLOUD_BACKUP_TIME="${NEXTCLOUD_BACKUP_TIME}"

export NEXTCLOUD_DEFAULT_PHONE_REGION=${NEXTCLOUD_DEFAULT_PHONE_REGION}

export OVERWRITEHOST=${OVERWRITEHOST}
export OVERWRITEPROTOCOL=${OVERWRITEPROTOCOL}

export GFARM_USER=${GFARM_USER}
export GFARM_DATA_PATH="${GFARM_DATA_PATH}"
export GFARM_BACKUP_PATH="${GFARM_BACKUP_PATH}"

export MYPROXY_SERVER=${MYPROXY_SERVER}
export MYPROXY_USER=${MYPROXY_USER}
export GSI_PROXY_HOURS=${GSI_PROXY_HOURS}

export TZ=${TZ}

export GFARM_ATTR_CACHE_TIMEOUT=${GFARM_ATTR_CACHE_TIMEOUT}
export FUSE_ENTRY_TIMEOUT=${FUSE_ENTRY_TIMEOUT}
export FUSE_NEGATIVE_TIMEOUT=${FUSE_NEGATIVE_TIMEOUT}
export FUSE_ATTR_TIMEOUT=${FUSE_ATTR_TIMEOUT}

### from official nextcloud/Dockerfile
export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
export PHP_UPLOAD_LIMIT=${PHP_UPLOAD_LIMIT}
EOF

### reload and export environment variables
source /nc-gfarm/config.sh

print_dbpassword() {
    cat ${MYSQL_PASSWORD_FILE} | head -1
}

MYSQL_PASSWORD=$(print_dbpassword)

# unnecessary
#copy0 "${MYSQL_PASSWORD_FILE}" "${MYSQL_PASSWORD_FILE_FOR_USER}"

tmp1=$(mktemp)
cat <<EOF > $tmp1
[client]
password="${MYSQL_PASSWORD}"
EOF
copy0 $tmp1 "${MYSQL_CONF}"
rm -f $tmp1

if [ ! -s "${MYSQL_ROOT_SH}" ]; then
    cat <<EOF > "${MYSQL_ROOT_SH}"
mysql --defaults-file="${MYSQL_CONF}" \
    -h ${MYSQL_HOST} \
    -u root
EOF
    chmod +x "${MYSQL_ROOT_SH}"
fi

copy0 "${NEXTCLOUD_ADMIN_PASSWORD_FILE}" "${NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER}"
mkdir -p "${FLAG_DIR}"

cp "${GFARM2_CONF_ORIG}" "${GFARM_CONF}"
echo "attr_cache_timeout ${GFARM_ATTR_CACHE_TIMEOUT}" >> "${GFARM_CONF}"
chown0 "${GFARM_CONF}"

if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -eq 1 ]; then
    GFARM_USERMAP="${HOMEDIR}/.gfarm_usermap"
    echo "${GFARM_USER} ${NEXTCLOUD_USER}" > "${GFARM_USERMAP}"
    chown0 "${GFARM_USERMAP}"

    echo >> "${GFARM_CONF}"
    echo "local_user_map ${GFARM_USERMAP}" >> "${GFARM_CONF}"

    if [ -s "${GFARM2RC_ORIG}" ]; then
        copy0 "${GFARM2RC_ORIG}" "${GFARM2RC}"
    fi

    ### check gfarm_shared_key
    USE_GFARM_SHARED_KEY=0

    if [ -s "${GFARM_SHARED_KEY_ORIG}" ]; then
        "${COPY_GFARM_SHARED_KEY_SH}"
        while ! is_valid_gfarm_shared_key; do
            INFO "To start Nextcloud, you need to run ${COPY_GFARM_SHARED_KEY_SH}, waiting for ..."
            sleep 5
        done
        USE_GFARM_SHARED_KEY=1
    fi

    ### check X.509 proxy certificate
    USE_GSI=0

    if [ -d "${GSI_USER_DIR_ORIG}" ]; then
        copy0 "${GSI_USER_DIR_ORIG}" "${GSI_USER_DIR}"
        USE_GSI=1
    fi

    # copy from backup
    if [ -s "${GSI_USER_PROXY_BACKUP}" ]; then
        copy0 "${GSI_USER_PROXY_BACKUP}" "${GSI_USER_PROXY_FILE}"
        USE_GSI=1
    fi

    if [ -s "${GSI_USER_PROXY_ORIG}" ] && ! is_valid_proxy_cert; then
        "${COPY_GSI_USER_PROXY_SH}"
        USE_GSI=1
    fi

    if [ -f "${GRID_PROXY_PASSWORD_FILE}" ] && ! is_valid_proxy_cert; then
        cat "${GRID_PROXY_PASSWORD_FILE}" | \
            ${SUDO_USER} grid-proxy-init -pwstdin -hours "${GSI_PROXY_HOURS}"
        USE_GSI=1
    fi

    if [ -n "${MYPROXY_SERVER}" ] && ! is_valid_proxy_cert; then
        USE_GSI=1
        if [ -f "${MYPROXY_PASSWORD_FILE}" ]; then
            cat "${MYPROXY_PASSWORD_FILE}" | \
                ${SUDO_USER} myproxy-logon --stdin_pass \
                -s "${MYPROXY_SERVER}" -l "${MYPROXY_USER}" \
                -t "${GSI_PROXY_HOURS}"
        fi
    fi

    if [ ${USE_GSI} -eq 1 ]; then
        sleep_time=1
        sleep_max=5
        while ! is_valid_proxy_cert; do
            INFO "To start Nextcloud, you need to run ${GRID_PROXY_INIT_SH} or ${MYPROXY_LOGON_SH} or ${COPY_GSI_USER_PROXY_SH}, waiting for ..."
            sleep $sleep_time
            if [ $sleep_time -lt $sleep_max ]; then
                sleep_time=$((sleep_time + 1))
            fi
        done
    fi

    # for gfarm_check_online.sh
    gfarm_cred_status_set "${USE_GFARM_SHARED_KEY}" "${USE_GSI}"

    if [ ! -f ${INIT_FLAG_PATH} ]; then
        sed -i -e 's/^NAME_COMPATIBILITY=STRICT_RFC2818$/NAME_COMPATIBILITY=HYBRID/' /etc/grid-security/gsi.conf

        mkdir -p "${CRONTAB_DIR_PATH}"

        chown0 "${FLAG_DIR}"
        touch "${INIT_FLAG_PATH}"
    fi

    ### reset crontab
    rm -f "${CRONTAB_FILE_PATH}"
    cp -f "${CRONTAB_TEMPLATE}" "${CRONTAB_FILE_PATH}"
    # NOTE: owner of crontab-file is root only
    chown root "${CRONTAB_FILE_PATH}"

    if [ -n "${NEXTCLOUD_BACKUP_TIME}" ]; then
        echo "${NEXTCLOUD_BACKUP_TIME} ${BACKUP_SH}" >> "${CRONTAB_FILE_PATH}"
    fi
    if [ -n "${GFARM_CHECK_ONLINE_TIME}" ]; then
        echo "${GFARM_CHECK_ONLINE_TIME} ${GFARM_CHECK_ONLINE_SH}" >> "${CRONTAB_FILE_PATH}"
    fi
    if [ -n "${NEXTCLOUD_FILES_SCAN_TIME}" ]; then
        echo "${NEXTCLOUD_FILES_SCAN_TIME} ${FILES_SCAN_SH}" >> "${CRONTAB_FILE_PATH}"
    fi

    INFO "checking availability to Gfarm (wait for a while ...)"
    num_gfsd=$(${SUDO_USER} gfsched -n 1 | wc -l)
    if [ $num_gfsd -le 0 ]; then
        ERR "Not available to Gfarm"
        exit 1
    fi

    # backup GSI user proxy
    copy0 "${GSI_USER_PROXY_FILE}" "${GSI_USER_PROXY_BACKUP}"

    ${SUDO_USER} gfmkdir -p "${GFARM_DATA_PATH}"
    ${SUDO_USER} gfchmod 750 "${GFARM_DATA_PATH}"
fi # end of NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR


until mysqladmin --defaults-file="${MYSQL_CONF}" -h ${MYSQL_HOST} -u ${MYSQL_USER} ping; do
    INFO "waiting for starting mysql server (${MYSQL_HOST}) ..."
    sleep 1
done

if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -eq 1 ]; then
    FILE_NUM=$(count_dirent "${HTML_DIR}/")
    if [ ${FILE_NUM} -eq 0 ]; then  # empty
        if ${SUDO_USER} gftest -d "${GFARM_BACKUP_PATH}"; then
            "${RESTORE_SH}"
        fi
    fi
fi

if [ -f "${MAIN_CONFIG}" ]; then  # not initial startup
    # always override dbpassword
    cat <<EOF > "${DBPASSWORD_CONFIG}"
<?php
\$CONFIG['dbpassword'] = "${MYSQL_PASSWORD}";
EOF
    chown0 "${DBPASSWORD_CONFIG}"

    # after restore and config:system:set dbpassword
    cat <<EOF | sed -e "s;@PASSWORD@;${MYSQL_PASSWORD};" | "${MYSQL_ROOT_SH}"
SET PASSWORD FOR ${MYSQL_USER}@"%"=password('@PASSWORD@');
EOF
fi

if [ ${NEXTCLOUD_GFARM_DEBUG_SLEEP} -eq 1 ]; then
    exec sleep infinity
fi

# from: https://hub.docker.com/_/nextcloud/
# The install and update script is only triggered when a default
# command is used (apache-foreground or php-fpm). If you use a custom
# command you have to enable the install / update with
# NEXTCLOUD_UPDATE (default: 0)
# (default on nextcloud-gfarm: 1)
export NEXTCLOUD_UPDATE=${NEXTCLOUD_UPDATE:-1}

if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -eq 1 ]; then
    # not change for mountpoint
    export NEXTCLOUD_DATA_DIR="${DATA_DIR}"
else
    export NEXTCLOUD_DATA_DIR="${LOCAL_DATA_DIR}"
    if [ ! -f ${INIT_FLAG_PATH} ]; then
        chown0 "${LOCAL_DATA_DIR}"
        touch "${INIT_FLAG_PATH}"
    fi
fi
exec "$@"
