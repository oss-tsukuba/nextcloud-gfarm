#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

BACKUP_FLAG="${NEXTCLOUD_SPOOL_PATH}/backup"

# ${NEXTCLOUD_USER} only
[ $(whoami) = "${NEXTCLOUD_USER}" ] || exit 1

TMPDIR="$(mktemp --directory)"

remove_tmpdir()
{
    rm -f "${BACKUP_FLAG}"
    rm -rf "${TMPDIR}"
}

reset_on_error()
{
    ${OCC} maintenance:mode --off
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT


if [ -f "${BACKUP_FLAG}" ]; then
    WARN "another backup.sh is running"
    exit 1
fi
touch "${BACKUP_FLAG}"

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
tar czpf ${SYSTEM_ARCH} ${SYSTEM_DIR_NAME}
gzip -c ${DB_FILE_NAME} > ${DB_ARCH}

gfmkdir -p "${GFARM_BACKUP_PATH}"

if [ ${NEXTCLOUD_BACKUP_USE_GFCP} -eq 1 ] && type gfcp > /dev/null; then
    GFCP=gfcp
    GF_SCHEME="gfarm:"
else
    GFCP=gfreg
    GF_SCHEME=""
fi

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
    ENC="$1"
    NAME="$2"

    ENC_SUFFIX=".enc"
    SUFFIX=""
    SRC="${NAME}"
    if [ -n "${ENC}" ]; then
        SUFFIX="${ENC_SUFFIX}"
        SRC_ENC="${SRC}${SUFFIX}"
        enc "${ENC}" "${SRC}" "${SRC_ENC}"
        SRC="${SRC_ENC}"
    fi
    DST="${GFARM_BACKUP_PATH}/${NAME}${SUFFIX}"
    DST_TMP="${DST}.tmp"
    ${GFCP} "${SRC}" "${GF_SCHEME}${DST_TMP}"
    gfchmod 600 "${DST_TMP}"
    gfmv "${DST_TMP}" "${DST}"
}

INFO "Uploading to Gfarm...."
upload "" "${SYSTEM_ARCH}" &
p1=$!
# encrypt DB only
upload "${NEXTCLOUD_BACKUP_ENCRYPT}" "${DB_ARCH}" &
p2=$!
wait $p1
wait $p2

gfls -l "${GFARM_BACKUP_PATH}"
INFO "Backup is complete."
