#!/bin/bash

echo "[*] Zatrzymywanie routera Wi-Fi i przywracanie domyślnych ustawień..."

# 1. Zatrzymaj hostapd i dnsmasq
echo "[*] Zatrzymywanie hostapd i dnsmasq..."
sudo pkill hostapd
sudo pkill dnsmasq

# 2. Wyczyść iptables
echo "[*] Czyszczenie reguł iptables..."
sudo iptables -t nat -F
sudo iptables -F

# 3. Wyłącz przekazywanie pakietów
echo "[*] Wyłączanie przekazywania pakietów..."
sudo sysctl -w net.ipv4.ip_forward=0

# 4. Reset interfejsu wlan0
echo "[*] Resetowanie interfejsu wlan0..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
nmcli device set wlan0 managed yes
nmcli device connect wlan0
sudo ip link set wlan0 up

# 5. Informacja końcowa
echo "[✔] Router Wi-Fi zatrzymany. wlan0 ponownie zarządzany przez NetworkManager."
