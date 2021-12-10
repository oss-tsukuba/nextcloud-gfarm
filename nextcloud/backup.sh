#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh

BACKUP_FLAG="${NEXTCLOUD_SPOOL_PATH}/backup"

# ${NEXTCLOUD_USER} only
[ $(whoami) = "${NEXTCLOUD_USER}" ] || exit 1

if [ -f "${MYSQL_PASSWORD_FILE_FOR_USER:-/}" ]; then
    PASSWORD="$(cat ${MYSQL_PASSWORD_FILE_FOR_USER})"
else
    PASSWORD="${MYSQL_PASSWORD}"
fi

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
    echo "another backup.sh is running" >&2
    exit 1
fi
touch "${BACKUP_FLAG}"

cd "${TMPDIR}"

${OCC} maintenance:mode --on
rsync -rlpt --exclude="/data/" "${HTML_DIR}/" ./${SYSTEM_DIR_NAME}/
mysqldump \
    -h ${MYSQL_HOST} \
    -u root \
    -p"${PASSWORD}" \
    -x --all-databases > ${DB_FILE_NAME}
${OCC} maintenance:mode --off

tar czpf ${SYSTEM_ARCH} ${SYSTEM_DIR_NAME}
gzip -c ${DB_FILE_NAME} > ${DB_ARCH}

gfmkdir -p "${GFARM_BACKUP_PATH}"

if which gfcp; then
    GFCP=gfcp
    GF_SCHEME="gfarm:"
else
    GFCP=gfreg
    GF_SCHEME=""
fi

${GFCP} ${SYSTEM_ARCH} "${GF_SCHEME}${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp"
${GFCP} ${DB_ARCH} "${GF_SCHEME}${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp"

gfchmod 600 "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp"

gfmv "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}"
gfmv "${GFARM_BACKUP_PATH}/${DB_ARCH}.tmp" "${GFARM_BACKUP_PATH}/${DB_ARCH}"

gfls -l "${GFARM_BACKUP_PATH}"
echo "Backup is complete."
