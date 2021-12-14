#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if maintenance_enabled; then
    WARN "gfarm_check_online.sh: maintenance:mode is enabled ... skipped"
    exit 1
fi

maintenance_on()
{
    ERR "expired Gfarm credential, or no accesibility to Gfarm"
    WARN "maintenance:mode --on"
    ${OCC} maintenance:mode --on
}

gfarm_cred_status_get
INVALID=1
if [ "${USE_GFARM_SHARED_KEY}" -eq 1 ]; then
    if is_valid_gfarm_shared_key; then
        INVALID=0
    fi
fi
if [ "${USE_GSI}" -eq 1 ]; then
    if is_valid_proxy_cert; then
        INVALID=0
    fi
fi
if [ ${INVALID} -ne 0 ]; then
    maintenance_on
    exit 2
fi

if ! gfarm2fs_is_mounted; then
    maintenance_on
    exit 3
fi

now=$(date)
if echo "${now}" | gfreg - "${GFARM_CHECK_ACCESS_FILE}"; then
    :
else
    maintenance_on
    exit 4
fi

if from_file=$(gfexport "${GFARM_CHECK_ACCESS_FILE}"); then
    :
else
    maintenance_on
    exit 6
fi

if [ "${from_file}" != "${now}" ]; then
    maintenance_on
    exit 5
fi

INFO "gfarm_check_online.sh: OK"
exit 0
