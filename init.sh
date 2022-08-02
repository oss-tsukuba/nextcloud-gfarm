#!/bin/bash

set -eu -o pipefail
#set -x

ENV_FILE_TEMPLATE="$1"
ENV_FILE_COMMON="template-common.env"
ENV_FILE_OVERRIDE="template-override.env"
ENV_FILE_MAIN="./config.env"

SECRET_DIR="./secrets"
DB_PASS_FILE="${SECRET_DIR}/db_password"
NEXTCLOUD_ADMIN_PASS_FILE="${SECRET_DIR}/nextcloud_admin_password"


COMPOSE_OVERRIDE="docker-compose.override.yml"
COMPOSE_HTTPS="docker-compose.override.yml.https"
COMPOSE_HTTP="docker-compose.override.yml.http"

REQUIRED="__REQUIRED__"

check_existence() {
    FILE="$1"

    if [ -s "${FILE}" ]; then
        echo "${FILE}: already exists"
        return 0
    fi
    return 1
}

gen_pass_stdout() {
    openssl rand -base64 36
}

create_pass_file() {
    FILE="$1"
    VAL="$2"

    echo "${VAL}" > "${FILE}"
    chmod 600 "${FILE}"
    echo "${FILE}: created"
}

read_input() {
    MSG="$1"
    DEFAULT="$2"
    read -p "${MSG} [${DEFAULT}]: " VAL
    if [ -n "${VAL}" ]; then
        echo "${VAL}"
    else
        if [ "${DEFAULT}" = "${REQUIRED}" ]; then
            return 1
        else
            echo "${DEFAULT}"
        fi
    fi
    return 0
}

if ! check_existence "${NEXTCLOUD_ADMIN_PASS_FILE}"; then
    PASS=$(read_input "${NEXTCLOUD_ADMIN_PASS_FILE} (empty:auto)" "")
    if [ -z "${PASS}" ]; then
        PASS=$(gen_pass_stdout)
    fi
    create_pass_file "${NEXTCLOUD_ADMIN_PASS_FILE}" "${PASS}"
fi

check_existence "${DB_PASS_FILE}" \
    || create_pass_file "${DB_PASS_FILE}" "$(gen_pass_stdout)"
chmod 700 "${SECRET_DIR}"

check_existence "${ENV_FILE_MAIN}" && exit 0

TMPFILE=$(mktemp)

cleanup() {
    rm -f "${TMPFILE}"
}

trap cleanup 1 2 15 ERR

PROTOCOL=

echo "Please input parameters: VALUE for KEY [DEFAULT]"
echo "Specifying empty and enter means using DEFAULT value."
echo "Specifying \"\" and enter means empty (or means disabled)."

if [ -f "${ENV_FILE_OVERRIDE}" ]; then
    ENV_FILE_TEMPLATE="${ENV_FILE_OVERRIDE}"
fi

NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR=0

IFS='
'
for kv in $(cat "${ENV_FILE_COMMON}" "${ENV_FILE_TEMPLATE}"); do
    [[ "$kv" =~ "=" ]] || continue
    echo "$kv" | grep -q "^\s*#.*$" && continue
    k=${kv%=*}
    v=${kv#*=}

    if [ ${NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR} = "0" ]; then
        # skip unnecessary keys
        case "${k}" in
            MYPROXY_USER) continue;;
            GFARM_USER) continue;;
            GFARM_DATA_PATH) continue;;
            GFARM_BACKUP_PATH) continue;;
        esac
    fi

    if VAL=$(read_input "$k" "$v"); then
        :
    else
        echo "ERROR" 1>&2
        exit 1
    fi
    echo "${k}=${VAL}" >> "${TMPFILE}"
    if [ "${k}" = "PROTOCOL" ]; then
        PROTOCOL="${VAL}"
    elif [ "${k}" = "NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR" ]; then
        NEXTCLOUD_GFARM_USE_GFARM_FOR_DATADIR="${VAL}"
    fi
done

if [ ! -e "${COMPOSE_OVERRIDE}" ]; then
    if [ "${PROTOCOL}" = "http" ]; then
        ln -s "${COMPOSE_HTTP}" "${COMPOSE_OVERRIDE}"
    else
        ln -s "${COMPOSE_HTTPS}" "${COMPOSE_OVERRIDE}"
    fi
fi

mv "${TMPFILE}" "${ENV_FILE_MAIN}"
echo "${ENV_FILE_MAIN}: created. Please check and correct parameters."

cleanup
