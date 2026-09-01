#!/bin/bash

GATEWAY="10.2.0.1"
HOOK_DIR="/usr/local/etc/vpnport.d"
LAST_PORT=""

while true
do
    date
    
    # Request UDP and TCP port mappings
    UDP_OUT=$(natpmpc -a 1 0 udp 60 -g "$GATEWAY" 2>&1)
    TCP_OUT=$(natpmpc -a 1 0 tcp 60 -g "$GATEWAY" 2>&1)

    # Extract mapped public port (4th token of the 'Mapped public port' line)
    PORT=$(echo "$TCP_OUT" | awk '/Mapped public port/ {print $4; exit}')

    if [ -z "$PORT" ]; then
        echo "ERROR with natpmpc output; retrying in 10s" >&2
        sleep 10
        continue
    fi

    # Trigger executable hooks if port has changed or initialized
    if [ "$PORT" != "$LAST_PORT" ]; then
        echo "Port assigned: $PORT"
        if [ -d "$HOOK_DIR" ]; then
            for hook in "$HOOK_DIR"/*; do
                if [ -f "$hook" ] && [ -x "$hook" ]; then
                    echo "Executing hook: $hook"
                    "$hook" "$PORT" || echo "Hook $hook failed with exit code $?" >&2
                fi
            done
        fi
        LAST_PORT="$PORT"
    fi

    sleep 45
    echo
done
