#!/bin/bash

set -eu
set -x

source ./.env

FROM=${GFARM_CONF_USER_DIR_FROM:-${HOME}}
TO=${GFARM_CONF_USER_DIR}

mkdir -p $TO

copy()
{
    SRC="$1"
    DST="$2"
    if [ -f "$SRC" ]; then
        cp -f "$SRC" "$DST"
    fi
}

copy "$FROM/.gfarm2rc" "$TO/gfarm2rc"
copy "$FROM/.gfarm_shared_key" "$TO/gfarm_shared_key"
copy "/tmp/x509up_u${UID}" "$TO/user_proxy_cert"
