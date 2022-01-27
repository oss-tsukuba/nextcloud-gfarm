#!/bin/sh

exec tail -n 0 -F /var/log/syslog 2> /dev/null
