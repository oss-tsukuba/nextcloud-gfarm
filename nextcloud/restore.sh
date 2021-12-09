#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail
#set -x

source /nc-gfarm/config.sh

# root only
[ $(id -u) -eq 0 ] || exit 1

if [ -f "${RESTORE_FLAG_PATH}" ]; then
    echo "restore.sh is ignored (already restored)" >&2
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

${SUDO_USER} gfexport "${GFARM_BACKUP_PATH}/${SYSTEM_ARCH}" > ${SYSTEM_ARCH}
${SUDO_USER} gfexport "${GFARM_BACKUP_PATH}/${DB_ARCH}" > ${DB_ARCH}

tar xzpf ${SYSTEM_ARCH}
rsync -a ${SYSTEM_DIR_NAME}/ "${HTML_DIR}/"
chown -R ${NEXTCLOUD_USER}:${NEXTCLOUD_USER} "${HTML_DIR}"

gunzip ${DB_ARCH}
mysql -h ${MYSQL_HOST} \
      -u root \
      -p"$(cat ${MYSQL_PASSWORD_FILE})" < ${DB_FILE_NAME}

touch "${RESTORE_FLAG_PATH}"
