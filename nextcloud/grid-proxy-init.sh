#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ ! -r "${GLOBUS_USER_KEY}" ]; then
    exit 0
fi

retry_command grid-proxy-init -hours "${GRID_PROXY_HOURS}"
