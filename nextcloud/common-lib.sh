ERR()
{
    echo >&2 "ERR: $@"
}

WARN()
{
    echo >&2 "WARN: $@"
}

INFO()
{
    echo >&2 "INFO: $@"
}

DEBUG()
{
    if [ ${NEXTCLOUD_GFARM_DEBUG} -eq 1 ]; then
        echo >&2 "DEBUG: $@"
    fi
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
    MOUNTPOINT="$1"
    SUBDIR="$2"

    # for debug
    #VALGRIND="valgrind --log-file=/tmp/valgrind-$$.log --leak-check=full --show-possibly-lost=no"
    VALGRIND=
    ${SUDO_USER} ${VALGRIND} gfarm2fs ${MNT_OPT} -o subdir="${SUBDIR}" "${MOUNTPOINT}"
}

umount_gfarm2fs()
{
    MOUNTPOINT="$1"
    #echo "umount ${MOUNTPOINT}"
    ${SUDO_USER} fusermount -u "${MOUNTPOINT}"
}

gfarm2fs_is_mounted()
{
    ${SUDO_USER} df "${DATA_DIR}" | egrep -q '^gfarm2fs\s'
}

retry_command()
{
    MAX_RETRY=5
    COUNT=1
    until "$@"; do
        [ ${COUNT} -ge ${MAX_RETRY} ] && return 1  # FAIL
        INFO "Retry [$(( COUNT++ ))/${MAX_RETRY}]: $@"
        sleep 1
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
    timeleft=$(timeleft_proxy_cert 2> /dev/null) || return $?
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

nextcloud_version()
{
    echo "NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION}"

    image_version=$(php -r "require \"${HTML_DIR}/version.php\"; echo implode('.', \$OC_Version);")
    echo "NEXTCLOUD_VERSION_REAL=${image_version}"
}

nextcloud_gfarm_version()
{
    if [ -z "${NEXTCLOUD_GFARM_VERSION:-}" ]; then
        source "${NCGFARM_DIR}/version.sh"
    fi
    if [ -z "${NEXTCLOUD_GFARM_COMMIT_HASH:-}" ]; then
        source "${NCGFARM_DIR}/commit_hash.sh"
    fi
    echo "NEXTCLOUD_GFARM_VERSION=${NEXTCLOUD_GFARM_VERSION}"
    echo "NEXTCLOUD_GFARM_COMMIT_HASH=${NEXTCLOUD_GFARM_COMMIT_HASH}"
}

count_dirent()
{
    ${SUDO_USER} ls -1a --ignore=. --ignore=.. "${1}" | wc -l
}
