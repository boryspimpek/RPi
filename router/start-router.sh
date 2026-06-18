#!/bin/bash

LOG_DIR=/home/borys/router/logs
HOSTAPD_LOG="$LOG_DIR/hostapd.log"
HOSTAPD_CONF=/home/borys/router/hostapd.conf
mkdir -p "$LOG_DIR"

echo "[*] Odłączanie wlan0 od NetworkManager..."
nmcli device set wlan0 managed no
nmcli device disconnect wlan0

echo "[*] Ustawianie adresu IP dla wlan0..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add 10.42.42.1/24 dev wlan0
sudo ip link set wlan0 up

echo "[*] Włączanie przekazywania pakietów..."
sudo sysctl -w net.ipv4.ip_forward=1

echo "[*] Konfiguracja iptables (NAT)..."
sudo iptables -t nat -F
sudo iptables -F
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

echo "[*] Restartowanie dnsmasq..."
sudo pkill dnsmasq

#echo "[*] Czekam na zwolnienie portu 53..."
#while sudo lsof -i :53 >/dev/null; do
#    echo "[!] Port 53 zajęty, czekam..."
#    sleep 1
#done

echo "[*] Uruchamianie dnsmasq z logowaniem..."
sudo dnsmasq --conf-file=/home/borys/router/dnsmasq.conf --log-facility=$LOG_DIR/dnsmasq.log

echo "[*] Restartowanie hostapd z logowaniem..."
sudo pkill hostapd

echo "[i] Logi hostapd nie będą widoczne tutaj: $LOG_DIR/hostapd.log bo jest jakis problem"

echo ""
echo "============================================================"

sudo hostapd $HOSTAPD_CONF 2>&1 #| awk '{ print strftime(\"[%Y-%m-%d %H:%M:%S]\"), \$0; fflush(); }' | tee $HOSTAPD_LOG"
