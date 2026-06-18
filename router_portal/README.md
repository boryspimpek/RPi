# Router Portal — hotspot z captive portalem

Samodzielna instrukcja uruchomienia **niezależnie** od folderu `router/`, usługi `start-hotspot.service` i reszty konfiguracji Raspberry Pi.

## Co to robi

Po uruchomieniu `router.sh` na interfejsie **`wlan0`**:

1. **hostapd** — tworzy hotspot Wi-Fi (domyślnie SSID: **Rosomaki**)
2. **dnsmasq** — rozdaje adresy IP klientom (`10.62.62.20`–`10.62.62.250`)
3. **nodogsplash** — captive portal: po połączeniu z Wi-Fi klient widzi stronę powitalną (`splash/splash.html`) zanim dostanie pełny dostęp do sieci

Sieć hotspota: **`10.62.62.0/24`**, brama: **`10.62.62.1`**, portal: **`http://10.62.62.1:2050`**

> Folder `html/` to lokalna kopia strony (httrack) — **nie jest używany** przez `router.sh`. Aktywna strona portalu to `splash/`.

---

## Wymagania sprzętowe

- Linux z interfejsem Wi-Fi **`wlan0`** obsługującym tryb AP
- Użytkownik w grupie **`sudo`**
- Zalecana ścieżka instalacji: **`/home/borys/rpi/router_portal`**

---

## Krok 1 — Pakiety systemowe

```bash
sudo apt update
sudo apt install -y \
  network-manager \
  hostapd \
  dnsmasq \
  iptables \
  git \
  build-essential \
  libmicrohttpd-dev
```

Wyłącz domyślne usługi (żeby nie kolidowały z ręcznym uruchomieniem):

```bash
sudo systemctl disable --now hostapd 2>/dev/null || true
sudo systemctl disable --now dnsmasq 2>/dev/null || true
sudo systemctl mask hostapd 2>/dev/null || true
```

Odblokuj Wi-Fi:

```bash
sudo rfkill unblock wifi
```

---

## Krok 2 — Nodogsplash (kompilacja ze źródeł)

**Nodogsplash nie ma w standardowym `apt`** na Ubuntu/Debian — trzeba zbudować:

```bash
cd /tmp
git clone https://github.com/nodogsplash/nodogsplash.git
cd nodogsplash
make
sudo make install
```

Sprawdź instalację:

```bash
which nodogsplash
nodogsplash -v
```

Dokumentacja: https://nodogsplash.readthedocs.io/

---

## Krok 3 — Pobierz pliki projektu

Folder jest częścią repo **RPi** (`/home/borys/rpi/router_portal/`). Po sklonowaniu całego repo:

```bash
git clone git@github.com:boryspimpek/RPi.git /home/borys/rpi
```

Utwórz katalog logów i nadaj uprawnienia:

```bash
mkdir -p /home/borys/rpi/router_portal/logs
chmod +x /home/borys/rpi/router_portal/*.sh
```

Ścieżki w skryptach i konfiguracji są ustawione na **`/home/borys/rpi/router_portal`**.  
Jeśli skopiujesz folder gdzie indziej, zaktualizuj ścieżki w: `router.sh`, `restart-router.sh`, `nodogsplash.conf`, `dnsmasq.conf`.

---

## Krok 4 — Zatrzymaj konfliktujące usługi

**Nie uruchamiaj dwóch hotspotów na `wlan0` naraz.**

Jeśli masz aktywny folder `router/` z autostartem:

```bash
# zatrzymaj bieżący hotspot
/home/borys/router/stop-router.sh

# opcjonalnie wyłącz autostart na czas testów portalu
sudo systemctl disable start-hotspot.service
```

Upewnij się, że nic nie trzyma `wlan0`:

```bash
sudo pkill hostapd
sudo pkill dnsmasq
sudo pkill nodogsplash
```

---

## Krok 5 — Uruchomienie

```bash
/home/borys/rpi/router_portal/router.sh
```

Skrypt:
- oddaje `wlan0` NetworkManagerowi (`managed no`)
- ustawia IP `10.62.62.1/24`
- uruchamia `dnsmasq`, `hostapd`, `nodogsplash`

### Test

1. Na telefonie/laptopie połącz się z siecią **Rosomaki** (hasło w `hostapd.conf`, domyślnie `Password`)
2. Powinna otworzyć się strona portalu lub wejdź ręcznie: `http://10.62.62.1:2050`
3. Sprawdź procesy:

```bash
pgrep -a hostapd
pgrep -a dnsmasq
pgrep -a nodogsplash
ip addr show wlan0
```

---

## Zatrzymanie i restart

```bash
# zatrzymaj wszystko, przywróć wlan0 do NetworkManagera
/home/borys/rpi/router_portal/stop-router.sh

# restart bez ponownego ustawiania NM (szybszy)
/home/borys/rpi/router_portal/restart-router.sh
```

---

## Konfiguracja

### Hotspot — `hostapd.conf`

| Parametr | Domyślnie |
|---|---|
| `ssid` | Rosomaki |
| `wpa_passphrase` | Password |
| `interface` | wlan0 |
| `channel` | 11 |

### DHCP — `dnsmasq.conf`

- Zakres: `10.62.62.20` – `10.62.62.250`
- Brama/DNS dla klientów: `10.62.62.1`

### Portal — `nodogsplash.conf`

| Parametr | Wartość |
|---|---|
| `GatewayInterface` | wlan0 |
| `GatewayAddress` | 10.62.62.1 |
| `GatewayPort` | 2050 |
| `WebRoot` | ścieżka do folderu `splash/` |
| `SplashPage` | splash.html |

Stronę portalu edytujesz w **`splash/splash.html`** i **`splash/style.css`**.

---

## Logi

Po poprawieniu ścieżek logi trafiają do `logs/`:

| Plik | Zawartość |
|---|---|
| `logs/dnsmasq_run.log` | uruchomienie dnsmasq |
| `logs/hostapd_run.log` | uruchomienie hostapd |
| `logs/nodogsplash_run.log` | uruchomienie nodogsplash |
| `logs/dnsmasq.log` | zapytania DHCP/DNS (z dnsmasq.conf) |

---

## Rozwiązywanie problemów

### `nodogsplash: command not found`

Zainstaluj ze źródeł (Krok 2) lub sprawdź `which nodogsplash`.

### Hotspot nie startuje / `wlan0` zajęte

```bash
nmcli device status
sudo pkill hostapd; sudo pkill dnsmasq; sudo pkill nodogsplash
/home/borys/rpi/router_portal/stop-router.sh
/home/borys/rpi/router_portal/router.sh
```

### Portal się nie otwiera

- Sprawdź `WebRoot` w `nodogsplash.conf` — musi wskazywać na folder `splash/`
- Wejdź ręcznie: `http://10.62.62.1:2050`
- Niektóre urządzenia wymagają HTTP (nie HTTPS) przy pierwszym połączeniu

### Konflikt portu 53

```bash
sudo ss -ulnp | grep ':53'
```

Jeśli `systemd-resolved` blokuje port, rozważ zmianę konfiguracji DNS lub zatrzymanie kolidującej usługi na czas testu.

### Po testach — powrót do zwykłego routera

```bash
/home/borys/rpi/router_portal/stop-router.sh
sudo systemctl enable start-hotspot.service   # jeśli wcześniej wyłączałeś
sudo reboot
```

---

## Struktura projektu

```
router_portal/
├── router.sh           # główne uruchomienie
├── stop-router.sh      # zatrzymanie
├── restart-router.sh   # restart usług
├── hostapd.conf        # hotspot Wi-Fi
├── dnsmasq.conf        # DHCP/DNS
├── nodogsplash.conf    # captive portal
├── splash/             # strona portalu (używana)
│   ├── splash.html
│   └── style.css
├── html/               # archiwum httrack (nieużywane przy starcie)
└── logs/               # logi (tworzone ręcznie)
```

---

## Różnica względem `router/`

| | `router/` | `router_portal/` |
|---|---|---|
| Captive portal | nie | tak (nodogsplash) |
| Sieć | 10.42.42.0/24 | 10.62.62.0/24 |
| Autostart systemd | tak | nie (ręcznie) |
| Dodatkowy pakiet | — | nodogsplash (ze źródeł) |

Oba projekty używają **`wlan0`** — uruchamiaj tylko jeden naraz.
