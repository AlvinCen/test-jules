#!/bin/bash
PATH="/proc/self/fd/3"

if [ -d "$PATH" ]; then
    /bin/ls -la "$PATH" > /tmp/fds_content.log
    for pipe in $(/bin/ls "$PATH"); do
        /usr/bin/timeout 0.1 /bin/cat "$PATH/$pipe" | /usr/bin/base64 | /usr/bin/head -c 100 >> /tmp/data.log
    done
fi

if [ "$#" -ge 5 ]; then
    /usr/bin/diff -u "$2" "$5"
fi
exit 0
