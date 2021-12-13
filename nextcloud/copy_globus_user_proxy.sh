#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ -s "${GLOBUS_USER_PROXY_ORIG}" ]; then
    NEXTCLOUD_USER_ID=$(id -u ${NEXTCLOUD_USER})
    PROXY_FILE="${GLOBUS_USER_PROXY_PREFIX}${NEXTCLOUD_USER_ID}"
    copy0 "${GLOBUS_USER_PROXY_ORIG}" "${PROXY_FILE}"
fi
