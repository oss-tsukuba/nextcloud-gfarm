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
# (The following parameters are not changed when restarting container)
if [ ! -f "${POST_FLAG_PATH}" ]; then
    ${OCC} maintenance:mode --on || true

    # NOTE: Cannot change the NEXTCLOUD_DATA_DIR
    #${OCC} config:system:set datadirectory --value="${DATA_DIR}"

    # may fail
    CURRENT_LOG_PATH=`${OCC} log:file | grep 'Log file:' | awk '{ print $3 }'` || true
    if [ "${CURRENT_LOG_PATH}" != "${NEXTCLOUD_LOG_PATH}" ]; then
        ${OCC} log:file --file "${NEXTCLOUD_LOG_PATH}"
        if [ -f "${CURRENT_LOG_PATH}" ]; then
            ${SUDO_USER} mv "${CURRENT_LOG_PATH}" "${NEXTCLOUD_LOG_PATH}"
        fi
    fi

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

# backup.sh requires ${NEXTCLOUD_LOG_PATH}
touch "${NEXTCLOUD_LOG_PATH}"

LINK_DATA="${HOMEDIR}/data"
[ -d "${LINK_DATA}" ] && rmdir "${LINK_DATA}"
${SUDO_USER} ln -s "${DATA_DIR}" "${LINK_DATA}"

# force online
${OCC} maintenance:mode --off || true

ARGS="$@"
pid=0
stop()
{
    if [ $pid -ne 0 ]; then
        echo "STOP: $ARGS" 1>&2
        kill $pid
    fi
    umount_gfarm2fs || true
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
