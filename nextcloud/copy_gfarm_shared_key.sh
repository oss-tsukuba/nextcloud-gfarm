#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu -o pipefail
#set -x

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if [ -f "${GFARM_SHARED_KEY_ORIG}" ]; then
    copy0 "${GFARM_SHARED_KEY_ORIG}" "${GFARM_SHARED_KEY}"
fi
