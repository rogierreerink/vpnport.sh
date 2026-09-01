#!/bin/bash

IFACE="${1}"
HOOK_DIR="/usr/local/etc/vpnport.d"
LAST_PORT=""

# Attempt to fetch the gateway IP from the routing table
GATEWAY=$(ip -4 route show dev "$IFACE" 2>/dev/null | awk '/via/ {print $3; exit}')

# Fallback: If no explicit 'via' route exists, compute the .1 gateway IP from the interface subnet
if [ -z "$GATEWAY" ]; then
    GATEWAY=$(ip -4 addr show dev "$IFACE" 2>/dev/null | awk -F'[ /]+' '/inet/ {print $3}' | sed 's/\.[0-9]*$/.1/')
fi

if [ -z "$GATEWAY" ]; then
    echo "ERROR: Could not resolve gateway IP for interface $IFACE" >&2
    exit 1
fi

while true
do
	echo "Refreshing port mappings"
    
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
