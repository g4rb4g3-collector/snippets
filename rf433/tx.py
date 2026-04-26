"""rf433 — replay a captured pulse train on Raspberry Pi Pico (MicroPython).

Drives TX_PIN HIGH/LOW for each microsecond duration in DATA, starting HIGH.
Paste the list printed by `main.py` into DATA and run.

Wiring: TX DATA -> GP15, 3V3/5V + common GND, 17.3 cm antenna.
"""
import time
from machine import Pin

TX_PIN = 15
REPEATS = 5
GAP_MS = 20            # idle gap between repeats

DATA = [23, 43]        # paste captured pulses here: [high1, low1, high2, low2, ...]


def busy_wait_us(us):
    end = time.ticks_add(time.ticks_us(), us)
    while time.ticks_diff(end, time.ticks_us()) > 0:
        pass


def transmit(pin, data):
    level = 1
    for duration in data:
        pin.value(level)
        busy_wait_us(duration)
        level ^= 1
    pin.value(0)


tx = Pin(TX_PIN, Pin.OUT, value=0)
print("rf433 tx: replaying {} pulses x{} on GP{}".format(len(DATA), REPEATS, TX_PIN))
for i in range(REPEATS):
    transmit(tx, DATA)
    time.sleep_ms(GAP_MS)
print("done")
