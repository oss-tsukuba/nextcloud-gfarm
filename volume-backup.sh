#!/bin/bash

set -eu

BASEDIR=$(dirname $(realpath $0))
source ${BASEDIR}/volume-backup-common.sh
eval $(cat config.env | egrep  '^(NEXTCLOUD_VERSION)=')

OUT_DIR="$1"

cd ${BASEDIR}

mkdir ${WORKDIR}

make occ-maintenancemode-on

# "tar: file changed as we read it" may occur
# immediately after starting maintenancemode-on
retry() {
    RETRY=5
    for i in $(seq ${RETRY}); do
        "$@" && return 0
    done
}

for vol in $(make -s volume-list); do
    retry ${DOCKER} run --rm \
           -v "${vol}:/${vol}:ro" \
           -v "${WORKDIR}:/backup" \
           --workdir / \
           --entrypoint tar \
           ${IMAGE} \
           cpf "/backup/volume-${vol}.tar.bz2" \
           --use-compress-prog=${COMPRESS_PROG} "${vol}"
done

cp -a ./${SECRETS_DIR_NAME} "${WORKDIR}/${SECRETS_DIR_NAME}"
cp -a ./${CONF_FILE_NAME} "${WORKDIR}/${CONF_FILE_NAME}"
make -s version > "${WORKDIR}/${VERSION_FILE_NAME}"

${DOCKER} run --rm \
           -v "${WORKDIR}:/${NAME}:ro" \
           -v "${OUT_DIR}:/output" \
           --workdir / \
           --entrypoint tar \
           ${IMAGE} \
           cpf "/output/${NAME_TAR}" -C / ${NAME}

#tar tvf ${OUT_DIR}/${NAME_TAR}
#tar xvf ${OUT_DIR}/${NAME_TAR} -O ${NAME}/${VERSION_FILE_NAME}

make occ-maintenancemode-off
