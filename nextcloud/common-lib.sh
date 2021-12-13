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

globus_cred_ok()
{
    timeleft=$(${SUDO_USER} grid-proxy-info -timeleft)
    [ "${timeleft}" -gt 0 ]
}
