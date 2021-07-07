#! /bin/sh

exec busybox crond -f -l 5 -L /dev/stdout
