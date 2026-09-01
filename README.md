# vpnport.sh

A lightweight Bash script that maintains dynamic VPN port forwards via NAT-PMP and runs executable drop-in scripts whenever the assigned port changes.

When connected to a VPN that assigns temporary inbound ports, this script sends periodic requests to keep the mapping open. If the assigned port changes, it executes any script placed in `/usr/local/etc/vpnport.d/`, passing the new port number as the first argument (`$1`).

## How It Works

1. Queries the VPN gateway using `natpmpc` every 45 seconds to keep UDP and TCP mappings alive.
2. Parses the assigned public port.
3. If the port changes or initial mapping occurs, it runs all executable files in `/usr/local/etc/vpnport.d/ <PORT>`.

---

## Quick Start (Example: Proton VPN + Transmission)

### 1. Install Dependencies

Ensure `natpmpc` is installed on your system.

```bash
sudo apt install natpmpc

```

### 2. Add the Main Script

Save `vpnport.sh` to `/usr/local/bin/vpnport.sh` and make it executable:

```bash
sudo chmod +x /usr/local/bin/vpnport.sh

```

### 3. Create the Hooks Directory and Transmission Hook

Create `/usr/local/etc/vpnport.d` and add a script to update Transmission's listening port via `transmission-remote`:

```bash
sudo mkdir -p /usr/local/etc/vpnport.d

```

Create `/usr/local/etc/vpnport.d/50-transmission.sh`:

```bash
#!/bin/bash
PORT="$1"

if [ -n "$PORT" ]; then
    # Add '-n username:password' if Transmission RPC authentication is enabled
    transmission-remote -p "$PORT"
fi

```

Make the hook script executable:

```bash
sudo chmod +x /usr/local/etc/vpnport.d/50-transmission.sh

```

### 4. Run via Systemd

Create `/etc/systemd/system/vpnport@.service` to tie the refresher to your WireGuard interface (e.g., `wg-quick@proton.service`):

```ini
[Unit]
Description=VPN NAT-PMP port forward refresher for %i
After=wg-quick@%i.service network-online.target
Wants=wg-quick@%i.service network-online.target
BindsTo=wg-quick@%i.service
PartOf=wg-quick@%i.service

[Service]
Type=simple
ExecStart=/usr/local/bin/vpnport.sh
Restart=always
RestartSec=5
User=debian-transmission
Group=debian-transmission

# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run /var/log

[Install]
WantedBy=wg-quick@%i.service

```

Enable and start the service for your WireGuard connection (replace `proton` with your WireGuard interface name):

```bash
sudo systemctl enable --now vpnport@proton.service

```
