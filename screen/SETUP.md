# Instrukcja odtworzenia ekranu OLED po formatowaniu dysku

Zakłada: Ubuntu / Raspberry Pi OS na Raspberry Pi, użytkownik `borys`, ekran SH1106 128×64 na I2C (adres `0x3c`, magistrala `i2c-1`).

---

## Przed formatowaniem — zrób kopię

Skopiuj gdzieś poza dysk (pendrive, inny komputer):

```
/home/borys/screen/screen.py
```

Resztę (`screen_env`) odtworzysz od zera — nie ma sensu kopiować całego venv.

---

## Krok 1 — Włącz I2C w konfiguracji boot

Edytuj plik (na nowszym Pi):

```bash
sudo nano /boot/firmware/config.txt
```

Upewnij się, że jest ta linia (odkomentuj lub dodaj):

```
dtparam=i2c_arm=on
```

Zapisz i **zrestartuj**:

```bash
sudo reboot
```

Po restarcie sprawdź, czy magistrala istnieje:

```bash
ls -l /dev/i2c-1
i2cdetect -y 1
```

Powinieneś zobaczyć `3c` w tabeli — to Twój ekran.

---

## Krok 2 — Dodaj użytkownika do grupy `i2c`

Bez tego Python nie ma dostępu do `/dev/i2c-1`:

```bash
sudo usermod -aG i2c borys
```

**Wyloguj się i zaloguj ponownie** (albo zrestartuj), żeby grupa zadziałała:

```bash
groups
# powinno być: ... i2c ...
```

---

## Krok 3 — Zainstaluj pakiety systemowe

```bash
sudo apt update
sudo apt install -y i2c-tools python3-venv python3-pip iw
```

| Pakiet | Po co |
|---|---|
| `i2c-tools` | `i2cdetect`, dostęp do I2C |
| `python3-venv` | tworzenie `screen_env` |
| `python3-pip` | instalacja bibliotek Python |
| `iw` | odczyt SSID WiFi w `screen.py` |

---

## Krok 4 — Utwórz folder projektu i skopiuj skrypt

```bash
mkdir -p /home/borys/screen
```

Wklej tam swój `screen.py` (z kopii zapasowej). Albo skopiuj z pendrive:

```bash
cp /ścieżka/do/kopii/screen.py /home/borys/screen/screen.py
```

---

## Krok 5 — Utwórz wirtualne środowisko Python

```bash
cd /home/borys/screen
python3 -m venv screen_env
screen_env/bin/pip install --upgrade pip
screen_env/bin/pip install luma.oled pillow psutil
```

To wystarczy — `luma.oled` sam ściągnie zależności (`luma.core`, `smbus2` itd.).

Szybki test ręczny (Ctrl+C żeby przerwać):

```bash
screen_env/bin/python3 screen.py
```

Jeśli ekran pokazuje dane — działa.

---

## Krok 6 — Utwórz usługę systemd (autostart przy boot)

```bash
sudo nano /etc/systemd/system/screen.service
```

Wklej całą zawartość:

```ini
[Unit]
Description=OLED Screen Stats Display
DefaultDependencies=no
After=local-fs.target
Before=network.target

[Service]
ExecStart=/home/borys/screen/screen_env/bin/python3 /home/borys/screen/screen.py
WorkingDirectory=/home/borys/screen/
StandardOutput=inherit
StandardError=inherit
Restart=always
User=borys
Group=borys
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=sysinit.target
```

Włącz i uruchom:

```bash
sudo systemctl daemon-reload
sudo systemctl enable screen.service
sudo systemctl start screen.service
```

Sprawdź status:

```bash
sudo systemctl status screen.service
```

Logi:

```bash
journalctl -u screen.service -f
```

---

## Krok 7 — Weryfikacja końcowa

```bash
# usługa działa
systemctl is-active screen.service

# ekran widoczny na I2C
i2cdetect -y 1

# proces Pythona działa
ps aux | grep screen.py
```

---

## Podsumowanie — co gdzie ląduje

| Co | Gdzie |
|---|---|
| Włączenie I2C | `/boot/firmware/config.txt` → `dtparam=i2c_arm=on` |
| Uprawnienia | użytkownik `borys` w grupie `i2c` |
| Pakiety systemowe | `i2c-tools`, `python3-venv`, `python3-pip`, `iw` |
| Skrypt | `/home/borys/screen/screen.py` |
| Biblioteki Python | `/home/borys/screen/screen_env/` |
| Autostart | `/etc/systemd/system/screen.service` |

---

## Opcjonalne rzeczy z obecnej konfiguracji

Te **nie są wymagane** do ekranu, ale mogą być w systemie:

- `dtparam=spi=on` w `config.txt` — SPI, ekran go nie używa
- grupa `spi` — też niepotrzebna do tego projektu
- `gpio=17` + `dtoverlay=gpio-poweroff` — osobna funkcja wyłączania Pi przyciskiem

---

## Typowe problemy

| Problem | Rozwiązanie |
|---|---|
| `Permission denied` na I2C | `sudo usermod -aG i2c borys` + wyloguj/zaloguj |
| Brak `/dev/i2c-1` | sprawdź `dtparam=i2c_arm=on` i zrób reboot |
| `i2cdetect` nie pokazuje `3c` | sprawdź okablowanie SDA/SCL, zasilanie, adres |
| Usługa pada przy starcie | uruchom ręcznie `screen_env/bin/python3 screen.py` i zobacz błąd |
| `Failed to connect to system scope bus` w logach | nieszkodliwe — usługa startuje bardzo wcześnie; ekran i tak działa |
