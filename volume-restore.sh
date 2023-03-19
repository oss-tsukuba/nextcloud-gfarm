#!/bin/bash

set -eu

BASEDIR=$(dirname $(realpath $0))
source ${BASEDIR}/volume-backup-common.sh

IN_FILE="${1:-}"
if [ -z "${IN_FILE}" ]; then
    echo "Usage: $0 INTPUT_FILE"
    exit 1
fi

if [ ! -f "${IN_FILE}" ]; then
    echo "${IN_FILE}: No such file"
    exit 1
fi

IN_FILE=$(realpath ${IN_FILE})
NAME_TAR=$(basename ${IN_FILE})

SUFFIX=${NAME_TAR##*.}
if [ ${SUFFIX} != "tar" ]; then
    exit 1
fi

call_on_error()
{
    :
}

cd ${BASEDIR}

${DOCKER} run --rm \
           -v "${TMPDIR}:/workdir" \
           -v "${IN_FILE}:/${NAME_TAR}:ro" \
           --workdir /workdir \
           --entrypoint tar \
           ${IMAGE_SIMPLE} \
           xf "/${NAME_TAR}"

NAME=$(ls -1 ${TMPDIR} | head -1)
WORKDIR=${TMPDIR}/${NAME}

# check
ls -l "${WORKDIR}"
cat "${WORKDIR}/${VERSION_FILE_NAME}"

exist_error() {
    FILE="$1"
    if [ -d "${FILE}" ]; then
        num=$(ls -1 "${FILE}" | wc -l)
        if [ ${num} -gt 0 ]; then
            echo "ERROR: ${FILE}: not empty directory"
            exit 1
        fi
    elif [ -e "${FILE}" ]; then
        echo "ERROR: ${FILE}: file exists"
        exit 1
    fi
}

for name in "${BACKUP_FILES[@]}"; do
    exist_error "./${name}"
done

for name in "${BACKUP_FILES[@]}"; do
    cp -pr  "${WORKDIR}/${name}" "./${name}"
done

# COMPOSE is ready.

yesno() {
        read -p "$1 (y/N): " YN; \
        case "$YN" in [yY]*) true;; \
        *) echo "Aborted (${YN})"; false;; \
        esac
}

num=$(make -s volume-list 2> /dev/null | wc -l)
if [ ${num} -gt 0 ]; then
    yesno "ERASE ALL LOCAL DATA. Continue?" || exit 1
    # remove old volumes
    make down-REMOVE_VOLUMES_FORCE
fi

# create empty volumes
${COMPOSE} up --no-start

for vol in $(make -s volume-list); do
    echo "copying volume: ${vol}"
    ${DOCKER} run --rm \
              -v "${vol}:/${vol}:rw" \
              -v "${WORKDIR}:/workdir:ro" \
              --workdir / \
              --entrypoint tar \
              ${IMAGE} \
              xf "/workdir/volume-${vol}.tar.bz2" \
              --use-compress-prog=${COMPRESS_PROG}
done

make reborn
