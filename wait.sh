#!/bin/bash

set -eu
#set -x

URL_PATH="/"
NAME="Nextcloud-Gfarm"
CONT_NAME="nextcloud"
EXPECT_CODE='^30.*$'

SILENT="-s"
#SILENT=""

COMPOSE=$(make -s ECHO_COMPOSE)

eval $(cat config.env | egrep  '^(PROTOCOL|HTTP_PORT|HTTPS_PORT|SERVER_NAME)=')

if [ "${PROTOCOL}" = "https" ]; then
    PORT=${HTTPS_PORT:-443}
else
    PORT=${HTTP_PORT:-80}
fi

URL="${PROTOCOL}://${SERVER_NAME}:${PORT}${URL_PATH}"
RESOLVE="--resolve ${SERVER_NAME}:${PORT}:127.0.0.1"

container_exists()
{
    ${COMPOSE} exec ${CONT_NAME} true
}

http_get_code()
{
    curl ${SILENT} -k --noproxy '*' -w '%{http_code}' \
         ${RESOLVE} ${URL} -o /dev/null
}

echo -n "Waiting for ${NAME} startup..."
while :; do
    if ! container_exists; then
        make stop ${CONT_NAME}
        make logs | tail -20
        exit 1
    fi
    if CODE=$(http_get_code); then
        if [[ "$CODE" =~ ${EXPECT_CODE} ]]; then
            break
        fi
    fi
    echo -n .
    sleep 1
done
echo
echo "${NAME} is ready."
