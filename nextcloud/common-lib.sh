ERR()
{
    echo "ERR: $@" >&2
}

WARN()
{
    echo "WARN: $@" >&2
}

INFO()
{
    echo "INFO: $@" >&2
}

chown0()
{
    chown -R ${NEXTCLOUD_USER}:root "$@"
}

copy0()
{
    src="$1"
    dst="$2"

    [ "$src" == "$dst" ] && exit 1
    rm -rf "$dst"
    cp -pr "$src" "$dst"
    chmod -R go-rwx "$dst"
    chown0 "$dst"
}

mount_gfarm2fs()
{
    ${SUDO_USER} gfarm2fs ${MNT_OPT} "${DATA_DIR}"
}

gfarm2fs_is_mounted()
{
    ${SUDO_USER} df "${DATA_DIR}" | egrep -q '^gfarm2fs\s'
}

retry_command()
{
    MAX_RETRY=3
    COUNT=1
    until "$@"; do
        [ ${COUNT} -ge ${MAX_RETRY} ] && return 1  # FAIL
        INFO "Retry [$(( COUNT++ ))/${MAX_RETRY}]: $@"
    done
    return 0
}

timeleft_gfarm_shared_key()
{
    et=$(${SUDO_USER} gfkey -e) || return 1
    [ -n "${et}" ] || return 2
    et_sec=$(date --date="${et#expiration time is }" +%s) || return 3
    now=$(date +%s) || return 4
    echo $((et_sec - now)) || return 5
}

is_valid_gfarm_shared_key()
{
    timeleft=$(timeleft_gfarm_shared_key) || return $?
    [ "${timeleft}" -gt ${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD} ]
}

timeleft_proxy_cert()
{
    timeleft=$(${SUDO_USER} grid-proxy-info -timeleft) || return 1
    [ -n "${timeleft}" ] || return 2
    echo "${timeleft}"
}

is_valid_proxy_cert()
{
    timeleft=$(timeleft_proxy_cert) || return $?
    [ "${timeleft}" -gt ${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD} ]
}

gfarm_cred_status_set()
{
    echo "USE_GFARM_SHARED_KEY=${1}" > "${GFARM_CRED_STATUS_FILE}"
    echo "USE_GSI=${2}" >> "${GFARM_CRED_STATUS_FILE}"
}

gfarm_cred_status_get()
{
    source "${GFARM_CRED_STATUS_FILE}"
}

maintenance_enabled()
{
    ${OCC} maintenance:mode | grep -q "enabled"
}
