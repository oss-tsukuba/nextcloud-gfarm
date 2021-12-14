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
    df "${DATA_DIR}" | egrep -q '^gfarm2fs\s'
}

retry_command()
{
    MAX_RETRY=3
    COUNT=1
    until "$@"; do
        [ ${COUNT} -ge ${MAX_RETRY} ] && return 1  # FAIL
        echo "Retry [$(( COUNT++ ))/${MAX_RETRY}]: $@"
    done
    return 0
}

is_valid_gfarm_shared_key()
{
    et=$(${SUDO_USER} gfkey -e)
    [ -n "${et}" ] || return 1
    et_sec=$(date --date="${et#expiration time is }" +%s) || return 2
    now=$(date +%s) || return 3
    timeleft=$((et_sec - now)) || return 4
    [ "${timeleft}" -gt ${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD} ]
}

is_valid_proxy()
{
    timeleft=$(${SUDO_USER} grid-proxy-info -timeleft) || return 1
    [ "${timeleft}" -gt ${GFARM_CREDENTIAL_EXPIRATION_THRESHOLD} ]
}
