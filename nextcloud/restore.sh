#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

: ${RESTORE_TEST:=0}

# root only
[ $(id -u) -eq 0 ] || exit 1

if [ -f "${RESTORE_FLAG_PATH}" ]; then
    WARN "restore.sh is ignored (already restored)"
    exit 1
fi

TMPDIR=$(mktemp --directory)
ENC_SUFFIX=".enc"

#COMPRESS_PROG=bzip2
COMPRESS_PROG=pbzip2

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

USE_GFCP=0
if [ ${NEXTCLOUD_BACKUP_USE_GFCP} -eq 1 ] && type gfcp > /dev/null; then
    USE_GFCP=1
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
    NAME="$1"

    SUFFIX=""
    ENC=""
    SRC="${GFARM_BACKUP_PATH}/${NAME}"
    if ${SUDO_USER} gftest -f "${SRC}${ENC_SUFFIX}"; then
        SUFFIX="${ENC_SUFFIX}"
        SRC="${SRC}${SUFFIX}"
        ENC="${NEXTCLOUD_BACKUP_ENCRYPT}"
    fi
    DST="${NAME}"
    DST_TMP="${DST}${SUFFIX}"
    if [ $USE_GFCP -eq 1 ]; then
        ${SUDO_USER} gfcp "${GF_SCHEME}${SRC}" "${DST_TMP}"
    else
        ${SUDO_USER} gfexport "${SRC}" > "${DST_TMP}"
    fi
    if [ -n "${ENC}" ]; then
        dec "${ENC}" "${DST_TMP}" "${DST}"
    fi
}

INFO "Downloading from Gfarm...."
download "${SYSTEM_ARCH}" &
p1=$!
download "${DB_ARCH}" &
p2=$!
wait $p1
wait $p2

INFO "Decompressing...."

tar xpf ${SYSTEM_ARCH} --use-compress-prog=${COMPRESS_PROG}
${COMPRESS_PROG} -d ${DB_ARCH}

if [ ${RESTORE_TEST} -eq 1 ]; then
    ls -l
    ls -l ${SYSTEM_DIR_NAME}/
    INFO "Restore test ... PASS"
    exit 0
fi

INFO "Copying backup files...."

rsync -a ${SYSTEM_DIR_NAME}/ "${HTML_DIR}/"
chown -R ${NEXTCLOUD_USER}:${NEXTCLOUD_USER} "${HTML_DIR}"

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
