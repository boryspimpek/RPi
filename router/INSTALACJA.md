# Automatyczny hotspot na Raspberry Pi

Instrukcja odtworzenia konfiguracji po czystej instalacji systemu.

## Jak to działa

Po każdym starcie systemu:

1. Usługa systemd czeka na sieć (`network-online.target`).
2. Skrypt `autostart/start-hotspot.sh` czeka **45 sekund** — NetworkManager ma czas połączyć się z zapisaną siecią Wi-Fi.
3. Sprawdza wszystkie karty Wi-Fi zarządzane przez NetworkManager:
   - jeśli dowolna karta jest połączona z routerem → hotspot **nie startuje**;
   - jeśli żadna karta nie jest połączona → uruchamia hotspot (**SSID: Rosomaki**) na `wlan0`.

Połączenie jest potwierdzane przez `iw dev INTERFEJS link`, więc własny AP nie
jest traktowany jako połączenie z routerem. Dostęp do internetu nie jest wymagany:
wystarczy połączenie z lokalną siecią. Sprawdzenie odbywa się raz przy starcie;
późniejsze rozłączenie nie uruchamia automatycznie hotspotu.

| Sytuacja | Efekt |
|---|---|
| Dowolna karta Wi-Fi połączona z routerem | Brak hotspota |
| Żadna karta Wi-Fi nie jest połączona | Hotspot na `wlan0` |
| Tylko Ethernet połączony | Hotspot na `wlan0`, internet przez kabel |

Hotspot udostępnia sieć `10.42.42.0/24`, brama i DNS: `10.42.42.1`.

NAT w `start-router.sh` jest skonfigurowany przez **`eth0`** (kabel). Klienci hotspota dostaną internet z kabla, jeśli jest podłączony. Bez kabla hotspot służy głównie do lokalnego dostępu (SSH, konfiguracja).

---

## Wymagania

- Raspberry Pi z interfejsem Wi-Fi `wlan0` (wbudowany lub pierwszy w systemie)
- NetworkManager (`nmcli`)
- Użytkownik w grupie `sudo`
- Ścieżka instalacji: **`/home/borys/rpi/router`** (skrypty mają wpisane ścieżki absolutne)

---

## Krok 1 — Pakiety systemowe

```bash
sudo apt update
sudo apt install -y network-manager hostapd dnsmasq iptables iw
```

Wyłącz domyślne usługi, żeby nie kolidowały z ręcznym uruchomieniem:

```bash
sudo systemctl disable --now hostapd 2>/dev/null || true
sudo systemctl disable --now dnsmasq 2>/dev/null || true
sudo systemctl mask hostapd 2>/dev/null || true
```

Odblokuj zarządzanie Wi-Fi przez NetworkManager (jeśli było wyłączone):

```bash
sudo rfkill unblock wifi
```

---

## Krok 2 — Skopiuj pliki routera

Skopiuj zawartość tego folderu do docelowej lokalizacji:

```bash
mkdir -p /home/borys/rpi/router
cp -a /ścieżka/do/kopii/router/. /home/borys/rpi/router/
```

Albo sklonuj repo `RPi` i weź stamtąd folder `router/`:

```bash
git clone git@github.com:boryspimpek/RPi.git /tmp/rpi
cp -a /tmp/rpi/router/. /home/borys/rpi/router/
```

Nadaj uprawnienia wykonywania:

```bash
chmod +x /home/borys/rpi/router/*.sh
chmod +x /home/borys/rpi/router/autostart/*.sh
mkdir -p /home/borys/rpi/router/logs
```

---

## Krok 3 — Dostosuj hotspot (opcjonalnie)

Edytuj `/home/borys/rpi/router/hostapd.conf`:

| Parametr | Domyślnie | Opis |
|---|---|---|
| `ssid` | `Rosomaki` | Nazwa sieci hotspota |
| `wpa_passphrase` | `Password` | Hasło WPA2 (min. 8 znaków) |
| `channel` | `11` | Kanał Wi-Fi |
| `interface` | `wlan0` | Interfejs AP — zostaw `wlan0`, jeśli nie wiesz po co zmieniać |

---

## Krok 4 — Usługa systemd (autostart)

Utwórz plik `/etc/systemd/system/start-hotspot.service`:

```ini
[Unit]
Description=Start hotspot if no WiFi is connected
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/borys/rpi/router/autostart/start-hotspot.sh

[Install]
WantedBy=multi-user.target
```

Włącz autostart:

```bash
sudo systemctl daemon-reload
sudo systemctl enable start-hotspot.service
```

---

## Krok 5 — Test

### Pełny test (restart)

```bash
sudo reboot
```

Po ~1 minucie sprawdź:

```bash
iw dev wlan0 info          # type AP = hotspot działa
ip addr show wlan0         # 10.42.42.1/24
systemctl status start-hotspot.service
tail -20 /home/borys/rpi/router/logs/hotspot-check.log
```

### Ręczny test bez restartu

```bash
/home/borys/rpi/router/stop-router.sh          # zatrzymaj, jeśli działa
sudo systemctl start start-hotspot.service # uruchom logikę autostartu
```

Połącz się z sieci **Rosomaki** (hasło z `hostapd.conf`), potem:

```bash
ssh borys@10.42.42.1
```

---

## Przydatne komendy

```bash
# Status hotspota i klientów
/home/borys/rpi/router/status.sh

# Zatrzymaj hotspot, przywróć wlan0 do NetworkManagera
/home/borys/rpi/router/stop-router.sh

# Restart hotspota (zatrzymaj → uruchom od nowa)
/home/borys/rpi/router/reset-router.sh

# Wyłącz autostart przy bootcie
sudo systemctl disable start-hotspot.service

# Włącz autostart z powrotem
sudo systemctl enable start-hotspot.service
```

---

## Logi

| Plik | Zawartość |
|---|---|
| `/home/borys/rpi/router/logs/hotspot-check.log` | Decyzja: hotspot tak/nie |
| `/home/borys/rpi/router/logs/dnsmasq.log` | DHCP i DNS |
| `journalctl -u start-hotspot.service` | Logi usługi systemd |

---

## Rozwiązywanie problemów

### Hotspot nie startuje po rebootcie

```bash
systemctl status start-hotspot.service
cat /home/borys/rpi/router/logs/hotspot-check.log
nmcli -t -f DEVICE,TYPE,STATE dev
```

Jeśli dowolna karta Wi-Fi jest połączona z routerem, hotspot celowo się nie włącza.

### `wlan0` nie wchodzi w tryb AP

```bash
sudo pkill hostapd
sudo pkill dnsmasq
nmcli device set wlan0 managed yes
/home/borys/rpi/router/start-router.sh
```

### Konflikt portu 53 (dnsmasq)

Sprawdź, czy coś innego nasłuchuje na porcie 53 (np. `systemd-resolved`):

```bash
sudo ss -ulnp | grep ':53'
```

### Inna ścieżka niż `/home/borys/rpi/router`

Zaktualizuj ścieżki w plikach:

- `autostart/start-hotspot.sh`
- `start-router.sh`
- `dnsmasq.conf`
- `/etc/systemd/system/start-hotspot.service`

Potem: `sudo systemctl daemon-reload`

---

## Struktura plików

```
router/
├── autostart/
│   └── start-hotspot.sh   # logika decyzyjna przy bootcie
├── hostapd.conf           # konfiguracja AP (SSID, hasło)
├── dnsmasq.conf           # DHCP dla klientów hotspota
├── start-router.sh        # uruchomienie hostapd + dnsmasq + NAT
├── stop-router.sh         # zatrzymanie i powrót do NM
├── reset-router.sh        # restart całego hotspota
├── status.sh              # podgląd stanu
├── drop-client.sh         # wyrzucenie klienta po MAC
├── watch-dns.sh           # podgląd logów DNS
└── logs/                  # logi runtime (tworzone automatycznie)
```
