# Instrukcja odtworzenia paska LED po formatowaniu dysku

Zakłada: Ubuntu / Raspberry Pi OS na Raspberry Pi 5 (lub równoważny z SPI), użytkownik `borys`, pasek NeoPixel WS281x sterowany przez SPI (`/dev/spidev0.0`, GPIO 10 / MOSI), **8 diod**, prędkość SPI **800 kHz**.

---

## Przed formatowaniem — zrób kopię

Skopiuj gdzieś poza dysk (pendrive, inny komputer):

```
/home/borys/led/led.py
```

Resztę (`.venv`) odtworzysz od zera — nie ma sensu kopiować całego venv.

---

## Krok 1 — Włącz SPI w konfiguracji boot

Edytuj plik:

```bash
sudo nano /boot/firmware/config.txt
```

Upewnij się, że jest ta linia (odkomentuj lub dodaj):

```
dtparam=spi=on
```

Zapisz i **zrestartuj**:

```bash
sudo reboot
```

Po restarcie sprawdź, czy urządzenie SPI istnieje:

```bash
ls -l /dev/spidev0.0
```

Powinieneś zobaczyć coś w stylu: `/dev/spidev0.0`

---

## Krok 2 — Dodaj użytkownika do grupy `spi`

Bez tego Python nie ma dostępu do `/dev/spidev0.0`:

```bash
sudo usermod -aG spi borys
```

**Wyloguj się i zaloguj ponownie** (albo zrestartuj), żeby grupa zadziałała:

```bash
groups
# powinno być: ... spi ...
```

---

## Krok 3 — Zainstaluj pakiety systemowe

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip python3-dev iputils-ping
```

| Pakiet | Po co |
|---|---|
| `python3-venv` | tworzenie `.venv` |
| `python3-pip` | instalacja bibliotek Python |
| `python3-dev` | kompilacja `spidev` (wymagane przy `pip install`) |
| `iputils-ping` | sprawdzanie sieci w `led.py` (`ping 8.8.8.8`) |

---

## Krok 4 — Utwórz folder projektu i skopiuj skrypt

```bash
mkdir -p /home/borys/led
```

Wklej tam swój `led.py` (z kopii zapasowej). Albo skopiuj z pendrive:

```bash
cp /ścieżka/do/kopii/led.py /home/borys/led/led.py
```

### Parametry w skrypcie

W `led.py` ustawione są:

```python
neo = Pi5Neo('/dev/spidev0.0', 8, 800)
```

| Parametr | Znaczenie |
|---|---|
| `/dev/spidev0.0` | magistrala SPI |
| `8` | liczba diod na pasku |
| `800` | prędkość SPI w kHz |

Jeśli masz inny pasek, zmień liczbę diod przed uruchomieniem.

---

## Krok 5 — Utwórz wirtualne środowisko Python

```bash
cd /home/borys/led
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install pi5neo
```

To wystarczy — `pi5neo` sam ściągnie zależność `spidev`.

Szybki test ręczny (Ctrl+C żeby przerwać):

```bash
.venv/bin/python led.py
```

Oczekiwane zachowanie:

1. Miganie na **niebiesko** — dopóki brak internetu (ping do `8.8.8.8`)
2. **Zielone** światło przez 10 sekund — gdy sieć działa
3. Cykl kolorów (czerwony → zielony → niebieski → fiolet) co 1 sekundę

---

## Krok 6 — Utwórz usługę systemd (autostart przy boot)

```bash
sudo nano /etc/systemd/system/led.service
```

Wklej całą zawartość:

```ini
[Unit]
Description=LED Rainbow Script Early Startup
DefaultDependencies=no
After=local-fs.target
Before=network.target

[Service]
ExecStart=/home/borys/led/.venv/bin/python /home/borys/led/led.py
WorkingDirectory=/home/borys/led
StandardOutput=inherit
StandardError=inherit
Restart=always
User=borys
Group=borys

[Install]
WantedBy=sysinit.target
```

Włącz i uruchom:

```bash
sudo systemctl daemon-reload
sudo systemctl enable led.service
sudo systemctl start led.service
```

Sprawdź status:

```bash
sudo systemctl status led.service
```

Logi:

```bash
journalctl -u led.service -f
```

---

## Krok 7 — Weryfikacja końcowa

```bash
# usługa działa
systemctl is-active led.service

# SPI dostępne
ls -l /dev/spidev0.0

# proces Pythona działa
ps aux | grep led.py
```

---

## Podsumowanie — co gdzie ląduje

| Co | Gdzie |
|---|---|
| Włączenie SPI | `/boot/firmware/config.txt` → `dtparam=spi=on` |
| Uprawnienia | użytkownik `borys` w grupie `spi` |
| Pakiety systemowe | `python3-venv`, `python3-pip`, `python3-dev`, `iputils-ping` |
| Skrypt | `/home/borys/led/led.py` |
| Biblioteki Python | `/home/borys/led/.venv/` |
| Autostart | `/etc/systemd/system/led.service` |

---

## Podłączenie sprzętu (przypomnienie)

Pasek NeoPixel WS281x jest sterowany przez **SPI MOSI (GPIO 10)** na Raspberry Pi 5. Biblioteka `pi5neo` wysyła dane przez `/dev/spidev0.0`.

Upewnij się, że:

- pasek ma osobne zasilanie (5 V) odpowiednie do liczby diod
- masa (GND) Raspberry Pi jest połączona z masą paska
- linia danych idzie na GPIO 10 (MOSI)

---

## Typowe problemy

| Problem | Rozwiązanie |
|---|---|
| `Permission denied` na SPI | `sudo usermod -aG spi borys` + wyloguj/zaloguj |
| Brak `/dev/spidev0.0` | sprawdź `dtparam=spi=on` i zrób reboot |
| Pasek nie świeci | sprawdź zasilanie, GND, liczbę diod w `led.py` |
| Usługa pada przy starcie | uruchom ręcznie `.venv/bin/python led.py` i zobacz błąd |
| Długie miganie na niebiesko | normalne przy starcie bez sieci; w logach widać `ping: Network is unreachable` |
| `spidev` nie instaluje się | zainstaluj `python3-dev` i spróbuj ponownie |

---

## Uwaga — ekran OLED + pasek LED na jednym Pi

Jeśli masz też ekran OLED, w `/boot/firmware/config.txt` potrzebujesz **obu** interfejsów:

```
dtparam=i2c_arm=on
dtparam=spi=on
```

Użytkownik `borys` powinien być w grupach **`i2c`** i **`spi`**. Instrukcja ekranu: `/home/borys/screen/SETUP.md`.
