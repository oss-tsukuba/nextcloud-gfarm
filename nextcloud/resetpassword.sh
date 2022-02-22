#!/bin/bash

set -eu
set -o pipefail
#set -x

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

USERNAME="$1"

# get OC_PASS from stdin
OC_PASS=$(cat)

export OC_PASS
${OCC} --password-from-env user:resetpassword "${USERNAME}"
