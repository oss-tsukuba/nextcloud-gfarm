#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

BACKUP_FLAG="/tmp/nc-gfarm-backup"
TMP_SUFFIX=".tmp"

# ${NEXTCLOUD_USER} only
[ $(whoami) = "${NEXTCLOUD_USER}" ] || exit 1

TMPDIR="$(mktemp --directory)"

remove_tmpdir()
{
    rm -rf "${BACKUP_FLAG}"
    rm -rf "${TMPDIR}"
}

reset_on_error()
{
    ${OCC} maintenance:mode --off
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT

# exclusive use
if ! mkdir "${BACKUP_FLAG}"; then
    WARN "another backup.sh is running"
    exit 1
fi

cd "${TMPDIR}"
INFO "Backup is starting...."

${OCC} maintenance:mode --on

rsync -rlpt --exclude="/data/" "${HTML_DIR}/" ./${SYSTEM_DIR_NAME}/

# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html
mysqldump --defaults-file="${MYSQL_CONF}" \
    --single-transaction \
    -h ${MYSQL_HOST} \
    -u ${MYSQL_USER} \
    ${MYSQL_DATABASE} > ${DB_FILE_NAME}

${OCC} maintenance:mode --off

INFO "Creating backup files...."
tar cpf ${SYSTEM_ARCH} --use-compress-prog=${COMPRESS_PROG} ${SYSTEM_DIR_NAME}
${COMPRESS_PROG} -c ${DB_FILE_NAME} > ${DB_ARCH}

gfmkdir -p "${GFARM_BACKUP_PATH}"

if [ ${NEXTCLOUD_BACKUP_USE_GFCP} -eq 1 ] && type gfcp > /dev/null; then
    GFCP=gfcp
    GF_SCHEME="gfarm:"
else
    GFCP=gfreg
    GF_SCHEME=""
fi

VERSION_FILE_NAME=$(basename ${NEXTCLOUD_GFARM_VERSION_FILE})
cp "${NEXTCLOUD_GFARM_VERSION_FILE}" "${VERSION_FILE_NAME}"

enc()
{
    ENC="$1"
    IN="$2"
    OUT="$3"
    PASS="${NEXTCLOUD_ADMIN_PASSWORD_FILE_FOR_USER}"

    openssl enc -${ENC} -e \
    -pbkdf2 -iter "${NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER}" \
    -in "${IN}" -out "${OUT}" -pass file:"$PASS"
}

upload()
{
    USE_ENC="$1"
    NAME="$2"

    if [ $USE_ENC -eq 1 ]; then
        ENC="${NEXTCLOUD_BACKUP_ENCRYPT}"
    else
        ENC=""
    fi
    SUFFIX=""
    SRC="${NAME}"
    if [ -n "${ENC}" ]; then
        SUFFIX="${ENC_SUFFIX}"
        SRC_ENC="${SRC}${SUFFIX}"
        enc "${ENC}" "${SRC}" "${SRC_ENC}"
        SRC="${SRC_ENC}"
    fi
    DST="${GFARM_BACKUP_PATH}/${NAME}${SUFFIX}"
    DST_TMP="${DST}${TMP_SUFFIX}"
    ${GFCP} "${SRC}" "${GF_SCHEME}${DST_TMP}"
    gfchmod 600 "${DST_TMP}"
    gfmv "${DST_TMP}" "${DST}"
}

INFO "Uploading to Gfarm...."
upload ${SYSTEM_ARCH_USE_ENC} "${SYSTEM_ARCH}" &
p1=$!
# encrypt DB only
upload ${DB_ARCH_USE_ENC} "${DB_ARCH}" &
p2=$!
upload 0 "${VERSION_FILE_NAME}" &
p3=$!
wait $p1
wait $p2
wait $p3

if [ ${KEEP_BACKUP_LOCAL} -eq 1 ]; then
    if [ ${DB_ARCH_USE_ENC} -eq 1 ]; then
        DB_ARCH_NAME="${DB_ARCH}${ENC_SUFFIX}"
    else
        DB_ARCH_NAME="${DB_ARCH}"
    fi
    mv "${DB_ARCH_NAME}" "${BACKUP_DIR}/${DB_ARCH_NAME}"

    if [ ${SYSTEM_ARCH_USE_ENC} -eq 1 ]; then
        SYSTEM_ARCH_NAME="${SYSTEM_ARCH}${ENC_SUFFIX}"
    else
        SYSTEM_ARCH_NAME="${SYSTEM_ARCH}"
    fi
    mv "${SYSTEM_ARCH_NAME}" "${BACKUP_DIR}/${SYSTEM_ARCH_NAME}"
    INFO "Backup local directory (${BACKUP_DIR}):"
    ls -l "${BACKUP_DIR}"
fi

INFO "Backup Gfarm directory (gfarm:${GFARM_BACKUP_PATH}):"
gfls -l "${GFARM_BACKUP_PATH}"
INFO "Backup is complete."
