#!/bin/bash

set -eu -o pipefail
#set -x

source /config.sh
source /common-lib.sh

if [ -f "${GFARM_SHARED_KEY_ORIG}" ]; then
    copy0 "${GFARM_SHARED_KEY_ORIG}" "${GFARM_SHARED_KEY}"
fi
