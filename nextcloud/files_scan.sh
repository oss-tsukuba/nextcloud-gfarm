#!/bin/bash

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

set -eu
set -o pipefail

source /nc-gfarm/config.sh
source ${CONFIG_LIB}

if maintenance_enabled; then
    WARN "files_scan.sh: maintenance:mode is enabled ... skipped"
    exit 1
fi

${OCC} files:scan --all
