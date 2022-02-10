#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

# root only
[ $(id -u) -eq 0 ] || exit 1

if [ -f "${RESTORE_FLAG_PATH}" ]; then
    WARN "restore.sh is ignored (already restored)"
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

INFO "Restore is starting...."

HAVE_GFCP=0
if [ ${NEXTCLOUD_BACKUP_USE_GFCP} -eq 1 ] && type gfcp > /dev/null; then
    HAVE_GFCP=1
fi

dec()
{
    ENC="$1"
    IN="$2"
    OUT="$3"
    PASS="${NEXTCLOUD_ADMIN_PASSWORD_FILE}"

    openssl enc -${ENC} -d \
    -pbkdf2 -iter "${NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER}" \
    -in "${IN}" -out "${OUT}" -pass file:"${PASS}"
}

download()
{
    ENC="$1"
    NAME="$2"

    ENC_SUFFIX=".enc"
    SUFFIX=""
    SRC="${GFARM_BACKUP_PATH}/${NAME}"
    if [ -n "${ENC}" ]; then
        SUFFIX="${ENC_SUFFIX}"
        SRC="${SRC}${SUFFIX}"
    fi
    DST="${NAME}"
    DST_ENC="${DST}${SUFFIX}"
    if [ $HAVE_GFCP -eq 1 ]; then
        ${SUDO_USER} gfcp "${GF_SCHEME}${SRC}" "${DST_ENC}"
    else
        ${SUDO_USER} gfexport "${SRC}" > "${DST_ENC}"
    fi
    if [ -n "${ENC}" ]; then
        dec "${ENC}" "${DST_ENC}" "${DST}"
    fi
}

download "" "${SYSTEM_ARCH}" &
p1=$!
# encrypt DB only
download "${NEXTCLOUD_BACKUP_ENCRYPT}" "${DB_ARCH}" &
p2=$!
wait $p1
wait $p2

tar xzpf ${SYSTEM_ARCH}
rsync -a ${SYSTEM_DIR_NAME}/ "${HTML_DIR}/"
chown -R ${NEXTCLOUD_USER}:${NEXTCLOUD_USER} "${HTML_DIR}"

gunzip ${DB_ARCH}
# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/restore.html
if mysql --defaults-file="${MYSQL_CONF}" \
      -h ${MYSQL_HOST} \
      -u root \
      ${MYSQL_DATABASE} < ${DB_FILE_NAME} \
   ; then
    :
else
    mysql --defaults-file="${MYSQL_CONF}" \
      -h ${MYSQL_HOST} \
      -u root < ${DB_FILE_NAME}
fi

touch "${RESTORE_FLAG_PATH}"
INFO "Restore is complete."
