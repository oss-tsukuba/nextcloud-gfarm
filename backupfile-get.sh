#!/bin/bash

# aggregate backup and configuration in a encrypted file.

BASEDIR=$(dirname $(realpath $0))
source ${BASEDIR}/backupfile-common.sh

COPY_DIR="$1"

mkdir "${WORKDIR}"
${DOCKER} cp "${SERVICE_ID}:${BACKUP_DIR}/" "${WORKDIR}/${BACKUP_DIR}"

ls -la "${WORKDIR}/${BACKUP_DIR}/"
NUM=$(ls -1 "${WORKDIR}/${BACKUP_DIR}/" | wc -l)
if [ $NUM -eq 0 ]; then
    echo 1>&2 "ERROR: empty backup directory ('make backup' required)"
    exit 1
fi

cp -a ./${SECRETS_NAME} "${WORKDIR}/${SECRETS_NAME}"
cp -a ./${CONF_NAME} "${WORKDIR}/${CONF_NAME}"

tar cf "${TMPDIR}/${NAME_TAR}" -C ${TMPDIR} "${NAME}"

tar tvf "${TMPDIR}/${NAME_TAR}"

enc()
{
    ENC="$1"
    IN="$2"
    OUT="$3"

    echo -n "INPUT PASSWORD (Echoed back):"
    openssl enc -${ENC} -e \
    -pbkdf2 -iter "${NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER}" \
    -in "${IN}" -out "${OUT}" -pass stdin
}

COPY_FILE=$(realpath "${COPY_DIR}/${NAME_ENC}")
enc ${NEXTCLOUD_BACKUP_ENCRYPT} "${TMPDIR}/${NAME_TAR}" "${COPY_FILE}"

P=$(realpath ${COPY_FILE})
echo "Saved: $P"
