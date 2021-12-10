#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ -z "${MYPROXY_SERVER}" ]; then
    exit 0
fi

retry_command myproxy-logon -s "${MYPROXY_SERVER}" -l "${MYPROXY_USER}" -t "${GRID_PROXY_HOURS}"
