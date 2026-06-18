#!/bin/bash

echo "=============================="
echo "🧠  STATUS ROUTERA Wi-Fi"
echo "=============================="

echo -e "\n⏱️  Czas działania systemu:"
uptime -p

echo -e "\n💻  Obciążenie systemu:"
top -b -n 1 | head -n 5

echo -e "\n🌡️   Temperatura CPU:"
vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp | awk '{printf "temp=%.1f°C\n", $1/1000}'

echo -e "\n    Logi z hostapd:"
tail /home/kali/router/logs/hostapd.log

echo -e "\n📋  Lista dzierżaw DHCP:"
cat /var/lib/misc/dnsmasq.leases 2>/dev/null || echo "Brak pliku dzierżaw"

echo -e "\n👥  Liczba klientów DHCP (aktywnych):"
wc -l /var/lib/misc/dnsmasq.leases 2>/dev/null | awk '{print $1 " klient(ów)"}'

echo -e "\n📶  Lista aktywnych klientów Wi-Fi (station dump):"
iw wlan0 station dump 2>/dev/null | grep -E 'Station|signal|tx bitrate' || echo "Brak aktywnych klientów"

echo -e "\n🧭  NetworkManager – status interfejsów:"
nmcli device status

echo -e "\n📶  iwconfig – status interfejsu Wi-Fi:"
iwconfig wlan0 2>/dev/null || echo "iwconfig: interfejs wlan0 nieaktywny lub brak na liście"

echo -e "\n🌍  Adres IP wlan0:"
ip -4 addr show wlan0 | grep inet || echo "Brak adresu IP na wlan0"

echo -e "\n    Sprawdzenie czy dziala dnsmasq:"
nslookup openai.com 10.42.42.1

echo -e "\n🧭  Trasa routingu i połączenie z Internetem:"
ip route show
ping -c 2 8.8.8.8

echo -e "\n🌐  iptables – reguły NAT i forwarding:"
echo "-- [NAT] POSTROUTING --"
sudo iptables -t nat -L POSTROUTING -v -n
echo "-- [FORWARD] --"
sudo iptables -L FORWARD -v -n

echo -e "\n📦  Użycie portu 53 (DNS):"
sudo lsof -i :53 || echo "Port 53 nie jest aktualnie zajęty"

#echo -e "\n🧷  NetworkManager – działania na wlan0:"
#sudo journalctl -u NetworkManager --no-pager | grep wlan0 | tail -n 15

#echo -e "\n🧩  Kernel – sterowniki i problemy sprzętowe (wlan0, brcmfmac, zasilanie):"
#sudo journalctl -k --no-pager | grep -E 'wlan0|brcm|firmware|power' | tail -n 15

echo -e "\n✅  Koniec raportu statusu routera."

