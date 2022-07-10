#!/bin/bash

# decrypt an aggregated backup file.

BASEDIR=$(dirname $(realpath $0))
source ${BASEDIR}/backupfile-common.sh

COPY_FILE="$1"
BN=$(basename ${COPY_FILE})
TARGET_NAME=${BN%*.tar.enc}

dec()
{
    ENC="$1"
    IN="$2"
    OUT="$3"

    echo -n "INPUT PASSWORD (Echoed back):"
    openssl enc -${ENC} -d \
    -pbkdf2 -iter "${NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER}" \
    -in "${IN}" -out "${OUT}" -pass stdin
}

TARGET_TAR="${TMPDIR}/${TARGET_NAME}.tar"
dec ${NEXTCLOUD_BACKUP_ENCRYPT} "${COPY_FILE}" "${TARGET_TAR}"

tar tvf "${TARGET_TAR}"
tar xvf "${TARGET_TAR}" -C "${TMPDIR}"

WORKDIR="${TMPDIR}/${TARGET_NAME}"

${DOCKER} cp "${WORKDIR}/${BACKUP_DIR}/." "${SERVICE_ID}:/${BACKUP_DIR}/"
echo "Copied: ${SERVICE}:${BACKUP_DIR}/"

${COMPOSE} exec ${SERVICE} ls "/${BACKUP_DIR}/"

cp -a "${WORKDIR}/${SECRETS_NAME}" "./${SECRETS_NAME}.${TARGET_NAME}"
echo "Copied: ./${SECRETS_NAME}.${TARGET_NAME}"

cp -a "${WORKDIR}/${CONF_NAME}" "./${CONF_NAME}.${TARGET_NAME}"
echo "Copied: ./${CONF_NAME}.${TARGET_NAME}"
