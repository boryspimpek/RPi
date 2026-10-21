#!/bin/bash

# Zmienna interfejsu
IFACE="wlan1"

LINK_INFO=$(iw "$IFACE" link 2>/dev/null)
DEV_INFO=$(iw dev "$IFACE" info 2>/dev/null)
IP_INFO=$(ip a show "$IFACE")

CONNECTED=$(echo "$LINK_INFO" | grep "Connected to" | awk '{print $3}')
SSID=$(echo "$LINK_INFO" | grep "SSID:" | awk '{print $2}')
FREQ=$(echo "$LINK_INFO" | grep "freq:" | awk '{print $2}')
SIGNAL=$(echo "$LINK_INFO" | grep "signal:" | awk '{print $2, $3}')
RX=$(echo "$LINK_INFO" | grep "RX:" | cut -d ':' -f2 | xargs)
TX=$(echo "$LINK_INFO" | grep "TX:" | cut -d ':' -f2 | xargs)

TYPE=$(echo "$DEV_INFO" | grep "type" | awk '{print $2}')
CHANNEL=$(echo "$DEV_INFO" | grep "channel" | awk '{print $2}')

STATE=$(echo "$IP_INFO" | awk '/state/ {for(i=1;i<=NF;i++) if ($i=="state") print $(i+1)}')
INET=$(echo "$IP_INFO" | grep "inet " | awk '{print $2}')
MAC=$(ip link show "$IFACE" | awk '/ether/ {print $2}')

GATEWAY=$(ip route | grep default | grep "$IFACE" | awk '{print $3}')

# Ustaw wartości domyślne
CONNECTED=${CONNECTED:-disconnected}
SSID=${SSID:--}
FREQ=${FREQ:--}
SIGNAL=${SIGNAL:--}
RX=${RX:-0}
TX=${TX:-0}
TYPE=${TYPE:--}
CHANNEL=${CHANNEL:--}
STATE=${STATE:-unknown}
INET=${INET:--}
MAC=${MAC:--}
GATEWAY=${GATEWAY:--}

# Wyświetlanie
clear
echo "========== Informacje o połączeniu =========="
echo "SSID:             $SSID"
echo "Adres MAC:        $CONNECTED"
echo "Frequency:        $FREQ MHz"
echo "Channel:          $CHANNEL"
echo "Signal strength:  $SIGNAL"
echo ""

echo "========== Parametry sieciowe =========="
echo "Stan interfejsu:  $STATE"
echo "Tryb pracy:       $TYPE"
echo "Adres MAC:        $MAC"
echo "Adres IPv4:       $INET"
echo "Brama domyślna:   $GATEWAY"
echo ""

echo "========== Statystyki ruchu =========="
echo "Odebrano (RX):    $RX"
echo "Wysłano (TX):     $TX"
echo ""
