from pi5neo import Pi5Neo
import time
import os

neo = Pi5Neo('/dev/spidev0.0', 8, 800)

def loading_animation():
    neo.fill_strip(0, 0, 255)  # niebieski
    neo.update_strip()
    time.sleep(0.5)
    neo.fill_strip(0, 0, 0)    # wyłącz
    neo.update_strip()
    time.sleep(0.5)

def is_system_ready():
    return os.system("ping -c 1 -W 1 8.8.8.8 > /dev/null") == 0

def green_light(duration):
    neo.fill_strip(0, 255, 0)
    neo.update_strip()
    time.sleep(duration)

def rainbow_cycle(neo, delay=1):
    colors = [
        (255, 0, 0),    # czerwony
        (0, 255, 0),    # zielony
        (0, 0, 255),    # niebieski
        (148, 0, 211)   # fiolet
    ]
    for color in colors:
        neo.fill_strip(*color)
        neo.update_strip()
        time.sleep(delay)

try:
    # 1. Pętla ładowania
    while not is_system_ready():
        loading_animation()
    
    # 2. Po wykryciu gotowości świeć na zielono 10 sekund
    green_light(10)
    
    # 3. Normalny tryb zmiany kolorów co sekundę
    while True:
        rainbow_cycle(neo, delay=1)

except KeyboardInterrupt:
    neo.fill_strip(0, 0, 0)
    neo.update_strip()
