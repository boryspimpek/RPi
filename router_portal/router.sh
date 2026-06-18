#!/bin/bash

echo "[*] Odłączanie wlan0 od NetworkManager..."
nmcli device set wlan0 managed no
nmcli device disconnect wlan0

echo "[*] Ustawianie adresu IP dla wlan0..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add 10.62.62.1/24 dev wlan0
sudo ip link set wlan0 up

echo "[*] Restart dnsmasq..."
sudo pkill dnsmasq
sleep 1
sudo dnsmasq -C /home/borys/rpi/router_portal/dnsmasq.conf >> /home/borys/rpi/router_portal/logs/dnsmasq_run.log 2>&1 &

echo "[*] Restart hostapd..."
sudo pkill hostapd
sleep 1
sudo hostapd /home/borys/rpi/router_portal/hostapd.conf >> /home/borys/rpi/router_portal/logs/hostapd_run.log 2>&1 &

echo "[*] Czekanie 3 sekundy na aktywację AP..."
sleep 3

echo "[*] Uruchamianie nodogsplash..."
sudo pkill nodogsplash
sleep 1
sudo nodogsplash -f -d 3 -c /home/borys/rpi/router_portal/nodogsplash.conf >> /home/borys/rpi/router_portal/logs/nodogsplash_run.log 2>&1
