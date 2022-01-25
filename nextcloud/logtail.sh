#!/bin/sh

exec tail -F /var/log/syslog 2> /dev/null
