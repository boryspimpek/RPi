from luma.core.interface.serial import i2c
from luma.oled.device import sh1106
from PIL import Image, ImageDraw, ImageFont
import time
import subprocess
import psutil
import re
import pwd
import os
from pathlib import Path

# Inicjalizacja wyświetlacza
serial = i2c(port=1, address=0x3c)
device = sh1106(serial, width=128, height=64)

# Domyślna czcionka
font = ImageFont.load_default()
ssh_user = pwd.getpwuid(os.getuid()).pw_name

def system_ready():
    result = subprocess.run(["systemctl", "is-active", "--quiet", "ssh.service"])
    return result.returncode == 0
    
def display_booting_screen():
    """Wyświetla ekran z komunikatem uruchamiania systemu"""
    image = Image.new('1', (device.width, device.height))
    draw = ImageDraw.Draw(image)

    draw.text((10, 20), "Booting system...", font=font, fill=255)
    draw.text((10, 40), "Please wait", font=font, fill=255)

    device.display(image)

# Funkcje systemowe
def getCPUtemperature():
    cmd = 'cat /sys/class/thermal/thermal_zone0/temp'
    try:
        temp = int(subprocess.check_output(cmd, shell=True).decode())
        return round(temp / 1000, 2)
    except Exception as e:
        print('getCPUtemperature: %s' % e)
        return 0.0

def getCPUuse():
    try:
        return psutil.cpu_percent(interval=1)
    except Exception as e:
        print('getCPUuse: %s' % e)
        return 0.0

def getRAMinfo():
    cmd = "free | awk 'NR==2 {print $2, $3}'"
    try:
        ram = subprocess.check_output(cmd, shell=True).decode().split()
        # Konwersja z kB do GB z dwoma miejscami po przecinku
        ram_GB = [round(int(val) / 1024 / 1024, 2) for val in ram]
        return ram_GB  # [Total_GB, Used_GB]
    except Exception as e:
        print('getRAMinfo: %s' % e)
        return [0.0, 0.0]

def get_wifi_interfaces():
    """Zwraca listę interfejsów WiFi np. ['wlan0', 'wlan1']"""
    cmd = "iw dev | grep Interface | awk '{print $2}'"
    try:
        interfaces = subprocess.check_output(cmd, shell=True).decode().split()
        return interfaces
    except Exception as e:
        print(f'get_wifi_interfaces: {e}')
        return []

def get_wifi_info(interface):
    """Zwraca SSID i IP dla podanego interfejsu WiFi"""
    # SSID
    cmd_ssid = f"iw dev {interface} link"
    ssid = "Not connected"
    try:
        output = subprocess.check_output(cmd_ssid, shell=True).decode()
        match = re.search(r'SSID:\s(.+)', output)
        if match:
            ssid = match.group(1)
    except Exception as e:
        print(f'get_wifi_info({interface}) - SSID: {e}')
    
    # IP
    cmd_ip = f"ip a show {interface} | grep 'inet ' | awk '{{print $2}}' | cut -d/ -f1"
    ip = "No IP"
    try:
        ip = subprocess.check_output(cmd_ip, shell=True).decode().strip()
    except Exception as e:
        print(f'get_wifi_info({interface}) - IP: {e}')
    
    return ssid, ip

def get_hotspot_config(interface):
    """Zwraca dane hotspotu tylko dla interfejsu działającego w trybie AP."""
    result = subprocess.run(
        ['iw', 'dev', interface, 'info'], capture_output=True, text=True
    )
    if result.returncode or not re.search(r'^\s*type AP\s*$', result.stdout, re.MULTILINE):
        return None
    try:
        config = {}
        path = Path(__file__).resolve().parent.parent / 'router' / 'hostapd.conf'
        for line in path.read_text().splitlines():
            if line.strip() and not line.lstrip().startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key.strip()] = value.strip()
        return config if config.get('interface') == interface else None
    except OSError as error:
        print(f'Nie można odczytać konfiguracji hotspotu: {error}')
        return None

def display_hotspot_credentials(config):
    # Zawijaj według szerokości w pikselach, bez obcinania hasła.
    rows = []
    for label, value in [('SSID:', config.get('ssid', '?')),
                         ('Haslo WiFi:', config.get('wpa_passphrase', '(brak)'))]:
        rows.append(label)
        part = ''
        for character in value:
            if part and font.getlength(part + character) > device.width:
                rows.append(part)
                part = ''
            part += character
        rows.append(part)
    for offset in range(0, len(rows), 4):
        image = Image.new('1', (device.width, device.height))
        draw = ImageDraw.Draw(image)
        draw.text((0, 0), 'HOTSPOT WIFI', font=font, fill=255)
        draw.line([(0, 12), (127, 12)], fill=255)
        for index, row in enumerate(rows[offset:offset + 4]):
            draw.text((0, 14 + index * 12), row, font=font, fill=255)
        device.display(image)
        time.sleep(5)

def display_wifi_interface_info(interface):
    ssid, ip = get_wifi_info(interface)
    hotspot = get_hotspot_config(interface)
    if hotspot:
        ssid = hotspot.get('ssid', ssid)
        display_hotspot_credentials(hotspot)

    image = Image.new('1', (device.width, device.height))
    draw = ImageDraw.Draw(image)
    
    label_x = 0
    value_x = 50
    line_height = 15
    
    draw.text((0, 0), f'{interface.upper()} INFO', font=font, fill=255)
    draw.line([(0, 12), (128, 12)], fill=255)

    draw.text((label_x, 1 * line_height + 5), 'SSID:', font=font, fill=255)
    ssid_display = ssid[:12] + "..." if len(ssid) > 15 else ssid
    draw.text((value_x, 1 * line_height + 5), ssid_display, font=font, fill=255)
    
    draw.text((label_x, 2 * line_height + 5), 'IP:', font=font, fill=255)
    draw.text((value_x, 2 * line_height + 5), ip, font=font, fill=255)

    draw.text((label_x, 3 * line_height + 5), 'SSH:', font=font, fill=255)
    draw.text((value_x, 3 * line_height + 5), ssh_user, font=font, fill=255)

    device.display(image)

def getIPadressEth0():
    cmd = "ip a show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1"
    try:
        ip_address = subprocess.check_output(cmd, shell=True).decode().strip()
        return ip_address if ip_address else "Not connected"
    except Exception as e:
        print('getIPadressEth0: %s' % e)
        return "No IP"

def display_system_info():
    """Wyświetla informacje systemowe: temperatura, CPU, RAM"""
    image = Image.new('1', (device.width, device.height))
    draw = ImageDraw.Draw(image)
    
    cpu_temp = getCPUtemperature()
    cpu_usage = getCPUuse()
    ram = getRAMinfo()
    eth0_ip = getIPadressEth0()
    
    label_x = 0
    value_x = 40
    line_height = 12
    
    # Nagłówek
    draw.text((0, 0), 'SYSTEM INFO', font=font, fill=255)
    draw.line([(0, 12), (128, 12)], fill=255)  # Linia pod nagłówkiem
    
    # Informacje systemowe
    draw.text((label_x, 1 * line_height + 5), 'Temp:', font=font, fill=255)
    draw.text((value_x, 1 * line_height + 5), f'{cpu_temp} C', font=font, fill=255)
    
    draw.text((label_x, 2 * line_height + 5), 'CPU:', font=font, fill=255)
    draw.text((value_x, 2 * line_height + 5), f'{cpu_usage} %', font=font, fill=255)
    
    draw.text((label_x, 3 * line_height + 5), 'RAM:', font=font, fill=255)
    draw.text((value_x, 3 * line_height + 5), f'{ram[1]} / {ram[0]} GB', font=font, fill=255)

    draw.text((label_x, 4 * line_height + 5), 'Eth IP:', font=font, fill=255)
    draw.text((value_x, 4 * line_height + 5), eth0_ip, font=font, fill=255)
    
    device.display(image)

def display_network_info():
    """Wyświetla informacje sieciowe: SSID, IP WiFi, IP Ethernet"""
    image = Image.new('1', (device.width, device.height))
    draw = ImageDraw.Draw(image)
    
    ip_wlan = getIPaddressWlan0()
    ip_eth = getIPadressEth0()
    ssid = getSSID()
    
    label_x = 0
    value_x = 45
    line_height = 15
    
    # Nagłówek
    draw.text((0, 0), 'NETWORK INFO', font=font, fill=255)
    draw.line([(0, 12), (128, 12)], fill=255)  # Linia pod nagłówkiem
    
    # Informacje sieciowe
    draw.text((label_x, 1 * line_height + 5), 'SSID:', font=font, fill=255)
    # Skracanie długich nazw SSID
    ssid_display = ssid[:12] + "..." if len(ssid) > 15 else ssid
    draw.text((value_x, 1 * line_height + 5), ssid_display, font=font, fill=255)
    
    draw.text((label_x, 2 * line_height + 5), 'WiFi:', font=font, fill=255)
    draw.text((value_x, 2 * line_height + 5), ip_wlan, font=font, fill=255)
    
    draw.text((label_x, 3 * line_height + 5), 'Eth:', font=font, fill=255)
    draw.text((value_x, 3 * line_height + 5), ip_eth, font=font, fill=255)
    
    device.display(image)

# Wyświetl ekran "booting..." dopóki system nie będzie gotowy
while not system_ready():
    display_booting_screen()
    time.sleep(1)

# Główna pętla
while True:
    # 1. Wyświetl system info
    display_system_info()
    time.sleep(5)

    # 2. Pobierz listę interfejsów WiFi
    wifi_interfaces = get_wifi_interfaces()

    # 3. Dla każdego interfejsu WiFi wyświetl ekran
    for iface in wifi_interfaces:
        display_wifi_interface_info(iface)
        time.sleep(2)
