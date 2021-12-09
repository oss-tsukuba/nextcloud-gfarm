chown0()
{
    chown -R ${NEXTCLOUD_USER}:root "$@"
}

copy0()
{
    src="$1"
    dst="$2"

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
