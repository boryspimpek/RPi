#!/bin/bash

# Kolory
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

get_wifi_interfaces() {
    # Znajdź wszystkie interfejsy Wi-Fi używając różnych metod
    local interfaces=()
    
    # Metoda 1: iw dev (najlepsze dla Wi-Fi)
    if command -v iw >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ $line =~ Interface[[:space:]]+([^[:space:]]+) ]]; then
                interfaces+=("${BASH_REMATCH[1]}")
            fi
        done < <(iw dev 2>/dev/null)
    fi
    
    # Metoda 2: Sprawdź /sys/class/net dla interfejsów wireless (backup)
    if [ ${#interfaces[@]} -eq 0 ]; then
        for iface in /sys/class/net/*/wireless; do
            if [ -d "$iface" ]; then
                basename_iface=$(basename "$(dirname "$iface")")
                interfaces+=("$basename_iface")
            fi
        done
    fi
    
    # Metoda 3: Sprawdź /proc/net/wireless (fallback)
    if [ ${#interfaces[@]} -eq 0 ] && [ -f /proc/net/wireless ]; then
        while read -r line; do
            if [[ $line =~ ^[[:space:]]*([^[:space:]]+): ]]; then
                interface_name="${BASH_REMATCH[1]}"
                # Usuń dwukropek na końcu jeśli istnieje
                interface_name="${interface_name%:}"
                interfaces+=("$interface_name")
            fi
        done < <(tail -n +3 /proc/net/wireless 2>/dev/null)
    fi
    
    # Usuń duplikaty i zwróć posortowaną listę
    printf '%s\n' "${interfaces[@]}" | sort -u
}

print_info() {
    local IFACE="$1"

    LINK_INFO=$(iw "$IFACE" link 2>/dev/null)
    DEV_INFO=$(iw dev "$IFACE" info 2>/dev/null)
    IP_INFO=$(ip a show "$IFACE" 2>/dev/null)

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
    MAC=$(ip link show "$IFACE" 2>/dev/null | awk '/ether/ {print $2}')

    GATEWAY=$(ip route | grep default | grep "$IFACE" | awk '{print $3}')

    # Ustaw wartości domyślne
    CONNECTED=${CONNECTED:-"nie podłączono"}
    SSID=${SSID:-"-"}
    FREQ=${FREQ:-"-"}
    SIGNAL=${SIGNAL:-"-"}
    RX=${RX:-"0"}
    TX=${TX:-"0"}
    TYPE=${TYPE:-"-"}    
    CHANNEL=${CHANNEL:-"-"}
    STATE=${STATE:-"nieznany"}
    INET=${INET:-"-"}
    MAC=${MAC:-"-"}
    GATEWAY=${GATEWAY:-"-"}

    echo -e "${CYAN}========== Informacje o połączeniu dla ${IFACE} ==========${RESET}"
    echo -e "${YELLOW}SSID:            ${RESET}$SSID"
    echo -e "${YELLOW}Connected to:    ${RESET}$CONNECTED" 
    echo -e "${YELLOW}Frequency:       ${RESET}$FREQ MHz"
    echo -e "${YELLOW}Channel:         ${RESET}$CHANNEL"
    echo -e "${YELLOW}Signal strength: ${RESET}$SIGNAL"
    echo ""

    echo -e "${CYAN}========== Parametry sieciowe ==========${RESET}"
    echo -e "${YELLOW}Stan interfejsu: ${RESET}$STATE"
    echo -e "${YELLOW}Tryb pracy:      ${RESET}$TYPE"
    echo -e "${YELLOW}Adres MAC:       ${RESET}$MAC"
    echo -e "${YELLOW}Adres IPv4:      ${RESET}$INET"
    echo -e "${YELLOW}Brama domyślna:  ${RESET}$GATEWAY"
    echo ""

    echo -e "${CYAN}========== Statystyki ruchu ==========${RESET}"
    echo -e "${YELLOW}Odebrano (RX):   ${RESET}$RX"
    echo -e "${YELLOW}Wysłano (TX):    ${RESET}$TX"
    echo -e "${CYAN}=========================================${RESET}\n"
}

print_saved_connections() {
    echo -e "${CYAN}========== Zapisane sieci Wi-Fi ==========${RESET}"
    if ! command -v nmcli >/dev/null 2>&1; then
        echo "nmcli nie jest dostępne."
        return
    fi

    python3 - <<'PYTHON'
import subprocess


def nmcli(*args):
    result = subprocess.run(
        ['nmcli', '--escape', 'no', *args],
        capture_output=True, text=True,
    )
    return result.stdout.rstrip('\n') if result.returncode == 0 else ''


def field(uuid, name, secret=False):
    options = ['--show-secrets'] if secret else []
    return nmcli(*options, '-g', name, 'connection', 'show', 'uuid', uuid)


networks = {}
for line in nmcli('-t', '-f', 'UUID,TYPE', 'connection', 'show').splitlines():
    uuid, _, kind = line.partition(':')
    if kind not in ('wifi', '802-11-wireless'):
        continue
    ssid = field(uuid, '802-11-wireless.ssid')
    if not ssid:
        continue
    network = networks.setdefault(ssid, {'devices': set(), 'passwords': set(), 'notes': set()})
    devices = field(uuid, 'GENERAL.DEVICES')
    network['devices'].update(
        device.strip() for device in devices.split(',')
        if device.strip() and device.strip() != '--'
    )
    password = field(uuid, '802-11-wireless-security.psk', secret=True)
    if password and password not in ('--', '<hidden>'):
        network['passwords'].add(password)
    else:
        security = field(uuid, '802-11-wireless-security.key-mgmt')
        if security in ('', '--', 'owe'):
            network['notes'].add('brak hasła Wi-Fi')
        elif security in ('wpa-psk', 'sae'):
            network['notes'].add('niedostępne lub niezapisane; spróbuj uruchomić przez sudo')
        else:
            network['notes'].add('inny typ zabezpieczeń: ' + security)

for ssid, network in sorted(networks.items()):
    print('\nSSID: ' + ssid)
    print('Aktywny na: ' + (', '.join(sorted(network['devices'])) or '—'))
    passwords = sorted(network['passwords'])
    if len(passwords) == 1:
        print('Hasło: ' + passwords[0])
    elif passwords:
        # Nie wybieraj przypadkowego hasła, jeśli profile mają różne wartości.
        print('Hasło: różne hasła w zapisanych profilach:')
        for password in passwords:
            print('  ' + password)
    else:
        print('Hasło: ' + '; '.join(sorted(network['notes'])))

if not networks:
    print('Brak zapisanych sieci Wi-Fi.')
print()
PYTHON
}

print_interfaces_summary() {
    local interfaces=("$@")
    
    echo -e "${BLUE}========== Podsumowanie interfejsów Wi-Fi ==========${RESET}"
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}❌ Nie znaleziono żadnych interfejsów Wi-Fi.${RESET}"
        echo -e "${YELLOW}💡 Sprawdź czy:${RESET}"
        echo "   - Sterowniki Wi-Fi są zainstalowane"
        echo "   - Interfejs Wi-Fi nie jest zablokowany (rfkill)"
        echo "   - System ma zainstalowane narzędzia iw lub wireless-tools"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}✅ Znaleziono ${#interfaces[@]} interfejs(ów) Wi-Fi:${RESET}"
    for iface in "${interfaces[@]}"; do
        echo "   - $iface"
    done
    echo -e "${CYAN}================================================${RESET}\n"
    return 0
}

# === WYKONANIE CAŁOŚCI ===
clear

#echo -e "${BLUE}🔍 Wyszukiwanie interfejsów Wi-Fi...${RESET}\n"

# Znajdź wszystkie interfejsy Wi-Fi
mapfile -t wifi_interfaces < <(get_wifi_interfaces)

# Wyświetl podsumowanie interfejsów
if ! print_interfaces_summary "${wifi_interfaces[@]}"; then
    exit 1
fi

# Wyświetl szczegółowe informacje dla każdego interfejsu
for iface in "${wifi_interfaces[@]}"; do
    print_info "$iface"
done

# Wyświetl zapisane połączenia
print_saved_connections