#!/bin/bash
set -euo pipefail
export LC_ALL=C

ROUTER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOGFILE="$ROUTER_DIR/logs/hotspot-check.log"
mkdir -p "$(dirname "$LOGFILE")"

echo "[$(date)] Sprawdzanie połączenia wszystkich kart WiFi..." >> "$LOGFILE"

# Daj NetworkManagerowi czas na autoconnect.
sleep 45

# Wymagamy połączenia klienta z routerem; własny AP się nie liczy.
DEVICES=$(nmcli -t -f DEVICE,TYPE,STATE device)
while IFS=: read -r interface type state; do
    if [[ "$type" == "wifi" && "$state" == "connected" ]] &&
       iw dev "$interface" link 2>/dev/null | grep -q '^Connected to '; then
        echo "[$(date)] $interface połączone z WiFi — hotspot niepotrzebny." >> "$LOGFILE"
        exit 0
    fi
done <<< "$DEVICES"

echo "[$(date)] Brak połączenia z routerem na wszystkich kartach WiFi — uruchamiam hotspot!" >> "$LOGFILE"
exec "$ROUTER_DIR/start-router.sh" >> "$LOGFILE" 2>&1
