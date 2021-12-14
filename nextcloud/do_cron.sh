#! /bin/sh

exec busybox crond -f -l 8 -L /dev/stdout
