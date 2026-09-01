#!/bin/bash

PORT="$1"

if [ -n "$PORT" ]; then
    # Adjust host, port, or auth (-n user:password) if non-default settings are used
    transmission-remote -p "$PORT"
fi
