#!/bin/bash

echo "[*] Restart routera..."

sudo pkill hostapd
sudo pkill dnsmasq
sudo pkill nodogsplash

sleep 1

sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add 10.62.62.1/24 dev wlan0
sudo ip link set wlan0 up

sleep 1

sudo hostapd /home/borys/rpi/router_portal/hostapd.conf >> /home/borys/rpi/router_portal/logs/hostapd_run.log 2>&1 &
sleep 2
sudo dnsmasq -C /home/borys/rpi/router_portal/dnsmasq.conf >> /home/borys/rpi/router_portal/logs/dnsmasq_run.log 2>&1 &
sleep 1
sudo nodogsplash -f -d 3 -c /home/borys/rpi/router_portal/nodogsplash.conf >> /home/borys/rpi/router_portal/logs/nodogsplash_run.log 2>&1 &

