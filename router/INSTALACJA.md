# Automatyczny hotspot na Raspberry Pi

Instrukcja odtworzenia konfiguracji po czystej instalacji systemu.

## Jak to działa

Po każdym starcie systemu:

1. Usługa systemd czeka na sieć (`network-online.target`).
2. Skrypt `autostart/start-hotspot.sh` czeka **45 sekund** — NetworkManager ma czas połączyć się z zapisaną siecią Wi-Fi.
3. Sprawdza stan **`wlan0`**:
   - jeśli `wlan0` jest połączone z Wi-Fi → hotspot **nie startuje**;
   - jeśli `wlan0` **nie** jest połączone → uruchamia hotspot (**SSID: Rosomaki**) na `wlan0`.

### Scenariusze

| Sytuacja | Efekt |
|---|---|
| Jedna karta Wi-Fi, znana sieć w zasięgu | `wlan0` łączy się z internetem, brak hotspota |
| Jedna karta Wi-Fi, obce miejsce | `wlan0` nie ma sieci → hotspot do komunikacji z RPi |
| Dwie karty Wi-Fi (np. `wlan0` + `wlan2`) | NM zwykle łączy internet na jednej karcie, `wlan0` zostaje wolne → hotspot na `wlan0` |

> **Uwaga:** Skrypt patrzy wyłącznie na `wlan0`. Nie sprawdza, czy inna karta (np. `wlan2`) ma internet.

Hotspot udostępnia sieć `10.42.42.0/24`, brama i DNS: `10.42.42.1`.

NAT w `start-router.sh` jest skonfigurowany przez **`eth0`** (kabel). Klienci hotspota dostaną internet z kabla, jeśli jest podłączony. Bez kabla hotspot służy głównie do lokalnego dostępu (SSH, konfiguracja).

---

## Wymagania

- Raspberry Pi z interfejsem Wi-Fi `wlan0` (wbudowany lub pierwszy w systemie)
- NetworkManager (`nmcli`)
- Użytkownik w grupie `sudo`
- Ścieżka instalacji: **`/home/borys/router`** (skrypty mają wpisane ścieżki absolutne)

---

## Krok 1 — Pakiety systemowe

```bash
sudo apt update
sudo apt install -y network-manager hostapd dnsmasq iptables
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
mkdir -p /home/borys/router
cp -a /ścieżka/do/kopii/router/. /home/borys/router/
```

Albo sklonuj repo `RPi` i weź stamtąd folder `router/`:

```bash
git clone git@github.com:boryspimpek/RPi.git /tmp/rpi
cp -a /tmp/rpi/router/. /home/borys/router/
```

Nadaj uprawnienia wykonywania:

```bash
chmod +x /home/borys/router/*.sh
chmod +x /home/borys/router/autostart/*.sh
mkdir -p /home/borys/router/logs
```

---

## Krok 3 — Dostosuj hotspot (opcjonalnie)

Edytuj `/home/borys/router/hostapd.conf`:

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
ExecStart=/home/borys/router/autostart/start-hotspot.sh

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
tail -20 /home/borys/router/logs/hotspot-check.log
```

### Ręczny test bez restartu

```bash
/home/borys/router/stop-router.sh          # zatrzymaj, jeśli działa
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
/home/borys/router/status.sh

# Zatrzymaj hotspot, przywróć wlan0 do NetworkManagera
/home/borys/router/stop-router.sh

# Restart hotspota (zatrzymaj → uruchom od nowa)
/home/borys/router/reset-router.sh

# Wyłącz autostart przy bootcie
sudo systemctl disable start-hotspot.service

# Włącz autostart z powrotem
sudo systemctl enable start-hotspot.service
```

---

## Logi

| Plik | Zawartość |
|---|---|
| `/home/borys/router/logs/hotspot-check.log` | Decyzja: hotspot tak/nie |
| `/home/borys/router/logs/dnsmasq.log` | DHCP i DNS |
| `journalctl -u start-hotspot.service` | Logi usługi systemd |

---

## Rozwiązywanie problemów

### Hotspot nie startuje po rebootcie

```bash
systemctl status start-hotspot.service
cat /home/borys/router/logs/hotspot-check.log
nmcli -t -f DEVICE,STATE dev | grep wlan0
```

Jeśli `wlan0` jest `connected`, hotspot celowo się nie włącza.

### `wlan0` nie wchodzi w tryb AP

```bash
sudo pkill hostapd
sudo pkill dnsmasq
nmcli device set wlan0 managed yes
/home/borys/router/start-router.sh
```

### Konflikt portu 53 (dnsmasq)

Sprawdź, czy coś innego nasłuchuje na porcie 53 (np. `systemd-resolved`):

```bash
sudo ss -ulnp | grep ':53'
```

### Inna ścieżka niż `/home/borys/router`

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
