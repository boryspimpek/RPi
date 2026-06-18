#!/bin/bash

LOGFILE=/home/borys/router/logs/hotspot-check.log
mkdir -p "$(dirname "$LOGFILE")"

echo "[$(date)] Sprawdzanie połączenia WiFi..." >> "$LOGFILE"

# Czekamy na ewentualne połączenie (autoconnect)
sleep 45

# Sprawdź status wlan0
WIFI_STATUS=$(nmcli -t -f DEVICE,STATE dev | grep '^wlan0:' | cut -d: -f2)

if [[ "$WIFI_STATUS" == "connected" ]]; then
    echo "[$(date)] wlan0 połączone z WiFi — hotspot niepotrzebny." >> "$LOGFILE"
else
    echo "[$(date)] wlan0 NIE jest połączone — uruchamiam hotspot!" >> "$LOGFILE"
    /home/borys/router/start-router.sh >> "$LOGFILE" 2>&1
fi
