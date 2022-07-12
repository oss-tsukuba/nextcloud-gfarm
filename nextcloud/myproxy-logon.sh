#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} -ne 1 ]; then
    # not covered
    exit 0
fi

FORCE=${1:-}

if [ -z "${MYPROXY_SERVER}" ]; then
    exit 0
fi

if [ "$FORCE" != '--force' ] && is_valid_proxy_cert; then
    exit 0
fi

retry_command myproxy-logon -s "${MYPROXY_SERVER}" -l "${MYPROXY_USER}" -t "${GSI_PROXY_HOURS}"
