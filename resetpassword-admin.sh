#!/bin/bash

set -eu
set -o pipefail
#set -x

COMPOSE_EXEC="$1"
CONTAINER_NAME="$2"

EXEC="${COMPOSE_EXEC} -T ${CONTAINER_NAME}"

DATE_S=$(date +%s)
PASS_FILE="./secrets/nextcloud_admin_password"
PASS_FILE_OLD="${PASS_FILE}.old.${DATE_S}"

ADMIN_NAME="admin"

read -p "Input new Nextcloud admin password: " ADMIN_PASS

mv "${PASS_FILE}" "${PASS_FILE_OLD}"

recover() {
    mv -f "${PASS_FILE_OLD}" "${PASS_FILE}"
    exit 1
}

trap recover ERR 1 2 15
echo "${ADMIN_PASS}" > "${PASS_FILE}"
chmod 600 "${PASS_FILE}"
echo "${ADMIN_PASS}" | ${EXEC} /nc-gfarm/resetpassword.sh "${ADMIN_NAME}"

echo "new password file: ${PASS_FILE}"
echo "old password file: ${PASS_FILE_OLD}"

echo "WARNING: Please run 'make reborn' and 'make backup' to change the password for encryption as soon as possible."
