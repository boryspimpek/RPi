#!/bin/bash

# Sprawdź, czy skrypt jest uruchomiony jako root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Uruchom ten skrypt jako root (np. sudo ./drop-client.sh)"
    exit 1
fi

echo "=============================="
echo "🚪 WYRZUCANIE KLIENTA Wi-Fi"
echo "=============================="

# Wyświetl listę aktywnych klientów
echo -e "\n📋 Aktywni klienci (MAC):"
iw wlan0 station dump | grep '^Station' | awk '{print $2}' || echo "Brak aktywnych klientów"

# Zapytaj o MAC klienta
read -p $'\n🔧 Podaj adres MAC klienta do wyrzucenia (np. aa:bb:cc:dd:ee:ff): ' MAC

# Walidacja podstawowa (format MAC)
if [[ ! $MAC =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]]; then
    echo "❌ Nieprawidłowy format adresu MAC."
    exit 1
fi

# Próba usunięcia klienta
echo "🚀 Wyrzucanie klienta $MAC..."
if iw dev wlan0 station del "$MAC"; then
    echo "✅ Klient $MAC został wyrzucony z sieci Wi-Fi."
else
    echo "❌ Nie udało się wyrzucić klienta. Adres MAC może być nieaktywny."
fi
