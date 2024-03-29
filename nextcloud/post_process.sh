#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

nextcloud_version > ${NEXTCLOUD_GFARM_VERSION_FILE}
nextcloud_gfarm_version >> ${NEXTCLOUD_GFARM_VERSION_FILE}

# force online
${OCC} maintenance:mode --off || true

create_mount_point()
{
    if [ -d "${TMP_DATA_DIR}" ]; then
        # NOTE: remove TMP_DATA_DIR
        ${SUDO_USER} rm -rf "${TMP_DATA_DIR}"
    fi
    ${SUDO_USER} mv "${DATA_DIR}" "${TMP_DATA_DIR}"
    ${SUDO_USER} mkdir -p "${DATA_DIR}"
    ${SUDO_USER} chmod 750 "${DATA_DIR}"
}

if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -eq 1 ]; then
    gfarm2fs_is_mounted && umount_gfarm2fs "${DATA_DIR}"
    # before mount_gfarm2fs
    if [ ! -d "${DATA_DIR}" ]; then
       ${SUDO_USER} mkdir -p "${DATA_DIR}"
    fi
    FILE_NUM=$(count_dirent "${DATA_DIR}")
    if [ ${FILE_NUM} -gt 0 ]; then  # not empty
        # new container ==> initial data files exist
        create_mount_point
    fi

    mount_gfarm2fs "${DATA_DIR}" "${GFARM_DATA_PATH}"

    if [ ${FILE_NUM} -gt 0 ]; then  # not empty
        GFARM_DIR_FILE_NUM=$(count_dirent "${DATA_DIR}")
        if [ ${GFARM_DIR_FILE_NUM} -eq 0 ]; then
            # empty GFARM_DATA_PATH ==> copy files
            ${SUDO_USER} rsync -vrlpt "${TMP_DATA_DIR}/" "${DATA_DIR}/"
        fi
    fi
else # NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR
    # ${DATA_DIR} is not used.
    if [ ! -h "${DATA_DIR}" -a -d "${DATA_DIR}" ]; then
        if [ -d "${TMP_DATA_DIR}" ]; then
            # NOTE: remove TMP_DATA_DIR
            ${SUDO_USER} rm -rf "${TMP_DATA_DIR}"
        fi
        ${SUDO_USER} mv "${DATA_DIR}" "${TMP_DATA_DIR}"
    fi
    # for compatibility, but not necessary
    ln -f -s "${LOCAL_DATA_DIR}" "${DATA_DIR}"
    chown -h "${NEXTCLOUD_USER}:${NEXTCLOUD_USER}" "${DATA_DIR}"
fi # NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR

#cat "${MAIN_CONFIG}"  # for debug

# rsync before calling occ
rsync -a --delete "${APP_GFARM_SRC_MAIN}/" "${APP_GFARM_DEST}/"
chown0 "${APP_GFARM_DEST}/"

mkdir -p ${LOGDIR}
chown0 ${LOGDIR}

# may fail
CURRENT_LOG_PATH=`${OCC} log:file | grep 'Log file:' | awk '{ print $3 }'` || true
if [ "${CURRENT_LOG_PATH}" != "${NEXTCLOUD_LOG_PATH}" ]; then
    # change the path of nextcloud.log
    ${OCC} log:file --file "${NEXTCLOUD_LOG_PATH}"
    if [ -f "${CURRENT_LOG_PATH}" ]; then
        ${SUDO_USER} mv "${CURRENT_LOG_PATH}" "${NEXTCLOUD_LOG_PATH}"
    fi
fi

# initialization after creating new (or renew) container
# (The following parameters are not changed when restarting container)
if [ ! -f "${POST_FLAG_PATH}" ]; then
    # NOTE: Cannot change the NEXTCLOUD_DATA_DIR
    #${OCC} config:system:set datadirectory --value="${DATA_DIR}"

    ${OCC} config:system:set skeletondirectory --value=''
    ${OCC} config:system:set default_phone_region --value="${NEXTCLOUD_DEFAULT_PHONE_REGION}"

    # update NEXTCLOUD_TRUSTED_DOMAINS
    ${OCC} config:system:delete trusted_domains
    index=0
    for domain in ${NEXTCLOUD_TRUSTED_DOMAINS}; do
        ${OCC} config:system:set trusted_domains $((index++)) --value=${domain}
    done

    touch "${POST_FLAG_PATH}"
fi

if [ ${NEXTCLOUD_GFARM_DEBUG} -eq 1 ]; then
    DEBUG_MODE=true
else
    DEBUG_MODE=false
fi
${OCC} config:system:set --type=boolean --value=${DEBUG_MODE} debug

# hide "Get your own free account" in public folder
${OCC} config:system:set simpleSignUpLink.shown --value=false --type=boolean

APPS_ENABLE="
files_external
files_external_gfarm
"
APPS_DISABLE="
firstrunwizard
"

# TODO ??? to enable background job
${OCC} app:disable files_external_gfarm || true
for APP in ${APPS_ENABLE}; do
    ${OCC} app:enable ${APP} || true
done
for APP in ${APPS_DISABLE}; do
    ${OCC} app:disable ${APP} || true
done

### oidc_login
if [ ${OIDC_LOGIN_ENABLE} -eq 1 ]; then
    ${OCC} app:enable oidc_login

    # overwrite
    sed -e "s;@OIDC_LOGIN_URL@;${OIDC_LOGIN_URL};" \
	-e "s;@OIDC_LOGIN_CLIENT_ID@;${OIDC_LOGIN_CLIENT_ID};" \
	-e "s;@OIDC_LOGIN_CLIENT_SECRET@;${OIDC_LOGIN_CLIENT_SECRET};" \
	-e "s;@OIDC_LOGIN_LOGOUT_URL@;${OIDC_LOGIN_LOGOUT_URL};" \
	-e "s;@OIDC_LOGIN_DEFAULT_QUOTA@;${OIDC_LOGIN_DEFAULT_QUOTA};" \
	"${OIDC_LOGIN_CONFIG_TEMPLATE}" \
	| dd of=${OIDC_LOGIN_CONFIG}
    chown0 ${OIDC_LOGIN_CONFIG}
else
    rm -f ${OIDC_LOGIN_CONFIG}
    ${OCC} app:disable oidc_login || true
fi

if [ -z "${TRUSTED_PROXIES:-}" ]; then
    # use dig (from bind9-dnsutils)
    # revproxy container name
    TRUSTED_PROXIES=$(dig revproxy +short) || TRUSTED_PROXIES=""
fi
export TRUSTED_PROXIES

ACCESS_LOG_FILE=/var/log/apache2/access.log
rm -f "${ACCESS_LOG_FILE}"
if [ "${HTTP_ACCESS_LOG}" -eq 1 ]; then
    ln -s /dev/stdout "${ACCESS_LOG_FILE}"
else
    ln -s /dev/null "${ACCESS_LOG_FILE}"
fi

# LimitRequestBody for Apache
# https://httpd.apache.org/docs/current/en/mod/core.html#limitrequestbody
echo "LimitRequestBody ${NEXTCLOUD_GFARM_UPLOAD_LIMIT}" > /etc/apache2/conf-enabled/upload_limit.conf

# disable chunked upload to avoid using the local temporary directory.
${OCC} config:app:set files max_chunk_size --value 0

# for backup.sh
touch "${NEXTCLOUD_LOG_PATH}"
mkdir -p "${BACKUP_DIR}"
chown0 "${BACKUP_DIR}"

LINK_DATA="${HOMEDIR}/data"
[ -d "${LINK_DATA}" -a ! -h "${LINK_DATA}" ] && rmdir "${LINK_DATA}"
[ -h "${LINK_DATA}" ] || ${SUDO_USER} ln -s "${DATA_DIR}" "${LINK_DATA}"

ARGS="$@"
pid=0
stop()
{
    if [ $pid -ne 0 ]; then
        echo "STOP: $ARGS" 1>&2
        kill $pid
    fi
    if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -eq 1 ]; then
        umount_gfarm2fs "${DATA_DIR}" || true
    fi
}

trap stop 1 2 15

# Do not use "exec" to use trap
"$@" &
pid=$!
set +e
wait $pid
status=$?
echo "EXIT(status=$status): $@" 1>&2
exit $status
