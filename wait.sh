#!/bin/bash

set -eu
#set -x

eval $(cat config.env | egrep '^(PROTOCOL|HTTP_PORT|HTTPS_PORT)=')

if [ $PROTOCOL = https ]; then
    PORT=$HTTPS_PORT
else
    PORT=$HTTP_PORT
fi

URL="${PROTOCOL}://localhost:${PORT}"

SILENT="-s"
#SILENT=""

while :; do
    if CODE=$(curl ${SILENT} -k -w '%{http_code}' ${URL}); then
        if [[ "$CODE" =~ ^30.*$ ]]; then
            break
        fi
    fi
    echo "Waiting for Nextcloud startup..."
    sleep 1
done

echo "Nextcloud is ready."
