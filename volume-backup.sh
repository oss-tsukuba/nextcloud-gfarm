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

${DOCKER} run --rm \
           -v "${WORKDIR}:/${NAME}:ro" \
           -v "${OUT_DIR}:/output" \
           --workdir / \
           --entrypoint tar \
           ${IMAGE} \
           cpf "/output/${NAME_TAR}" -C / ${NAME}

tar tvf ${OUT_DIR}/${NAME_TAR}

make occ-maintenancemode-off
