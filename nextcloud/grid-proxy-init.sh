#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

FORCE=${1:-}

if [ ! -s "${GLOBUS_USER_KEY}" ]; then
    exit 0
fi

if [ "$FORCE" != '--force' ] && globus_cred_ok; then
    exit 0
fi

retry_command grid-proxy-init -hours "${GRID_PROXY_HOURS}"
