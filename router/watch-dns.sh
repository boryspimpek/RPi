#!/bin/bash

LOGFILE="/home/borys/router/logs/dnsmasq.log"

echo "=============================="
echo "📡 ŚLEDZENIE ZAPYTAŃ DNS (dnsmasq)"
echo "Plik: $LOGFILE"
echo "Zatrzymaj: Ctrl+C"
echo "=============================="

sudo tail -f "$LOGFILE" | grep 'query\['
