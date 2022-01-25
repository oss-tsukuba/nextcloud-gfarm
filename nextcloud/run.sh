#!/bin/bash

ARGS="$@"

pid=0
stop()
{
    echo "STOP: $ARGS" 1>&2
    kill $pid
}

trap stop 1 2 15

"$@" &
pid=$!
wait $pid
status=$?
echo "DONE(status=$status): $@" 1>&2

# When one of the programs below finishes, terminate supervisord
# (pid=1) to stop the container.
kill 1
exit $status
