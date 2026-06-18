#!/bin/bash

echo "[*] Zatrzymywanie usług routera..."

# Zabij procesy
echo "[*] Zabijanie nodogsplash..."
sudo pkill nodogsplash

echo "[*] Zabijanie hostapd..."
sudo pkill hostapd

echo "[*] Zabijanie dnsmasq..."
sudo pkill dnsmasq

# Odłącz interfejs wlan0
echo "[*] Dezaktywacja interfejsu wlan0..."
sudo ip addr flush dev wlan0
sudo ip link set wlan0 down

# (Opcjonalnie) przywróć kontrolę NetworkManager
echo "[*] Przywracanie wlan0 do NetworkManager..."
nmcli device set wlan0 managed yes

echo "[*] Gotowe. Router został zatrzymany."
