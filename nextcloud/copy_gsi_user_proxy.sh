#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ -s "${GSI_USER_PROXY_ORIG}" ]; then
    copy0 "${GSI_USER_PROXY_ORIG}" "${GSI_USER_PROXY_FILE}"
fi
