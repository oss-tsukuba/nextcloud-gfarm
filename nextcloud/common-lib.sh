chown0() {
    chown -R ${NEXTCLOUD_USER}:root "$@"
}

copy0() {
    src="$1"
    dst="$2"

    rm -rf "$dst"
    cp -pr "$src" "$dst"
    chmod -R go-rwx "$dst"
    chown0 "$dst"
}
