#!/bin/sh

DIR=/etc/nginx/certs

for f in $(find ${DIR} -name *.crt); do
    echo "filename: $f"
    echo -n "    "
    openssl x509 -fingerprint -noout -sha1 -in $f
    echo -n "    "
    openssl x509 -fingerprint -noout -sha256 -in $f
done
