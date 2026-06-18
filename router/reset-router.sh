#!/bin/bash

ROUTER_DIR=/home/borys/router
LOG_DIR="$ROUTER_DIR/logs"

echo "[*] Resetowanie routera Wi-Fi..."

# 1. Zatrzymaj hostapd i dnsmasq
echo "[*] Zatrzymywanie hostapd i dnsmasq..."
sudo pkill hostapd
sudo pkill dnsmasq

# 2. Wyczyść iptables
echo "[*] Czyszczenie reguł iptables..."
sudo iptables -t nat -F
sudo iptables -F

# 3. Przywróć wlan0 (na wszelki wypadek)
echo "[*] Resetowanie interfejsu wlan0..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
nmcli device set wlan0 managed yes
nmcli device connect wlan0

# 4. Krótkie oczekiwanie
echo "[*] Oczekiwanie 2 sekundy..."
sleep 2

# 5. Ponowne odłączenie od NetworkManagera i restart routera
echo "[*] Ponowne uruchamianie routera Wi-Fi..."
nmcli device set wlan0 managed no

# 6. Uruchom start-router.sh
sudo "$ROUTER_DIR/start-router.sh"
