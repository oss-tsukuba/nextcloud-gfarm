#!/bin/bash

set -eu

BASEDIR=$(dirname $(realpath $0))
source ${BASEDIR}/volume-backup-common.sh

OUT_DIR="${1:-}"
if [ -z "${OUT_DIR}" ]; then
    echo "Usage: $0 OUTPUT_DIRECTORY"
    exit 1
fi

if [ ! -d "${OUT_DIR}" ]; then
    echo "${OUT_DIR}: No such directory"
    exit 1
fi

OUT_DIR=$(realpath ${OUT_DIR})

call_on_error()
{
    make occ-maintenancemode-off
}

NAME=nextcloud-gfarm-backup-$(date +%Y%m%d-%H%M)
NAME_TAR=${NAME}.tar
NAME_ENC=${NAME_TAR}.enc
WORKDIR=${TMPDIR}/${NAME}

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
    echo "copying volume: ${vol}"
    retry ${DOCKER} run --rm \
           -v "${vol}:/${vol}:ro" \
           -v "${WORKDIR}:/backup" \
           --workdir / \
           --entrypoint tar \
           ${IMAGE} \
           cpf "/backup/volume-${vol}.tar.bz2" \
           --use-compress-prog=${COMPRESS_PROG} "${vol}"
done

for name in "${BACKUP_FILES[@]}"; do
    cp -a "./${name}" "${WORKDIR}/${name}"
done
make -s version > "${WORKDIR}/${VERSION_FILE_NAME}"

${DOCKER} run --rm \
           -v "${WORKDIR}:/${NAME}:ro" \
           -v "${OUT_DIR}:/output" \
           --workdir / \
           --entrypoint tar \
           ${IMAGE} \
           cpf "/output/${NAME_TAR}" -C / ${NAME}

make occ-maintenancemode-off

P=$(realpath ${OUT_DIR}/${NAME_TAR})
echo "Backup file is created: ${P}"
