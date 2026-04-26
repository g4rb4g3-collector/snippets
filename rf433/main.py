"""rf433 — raw 433 MHz pulse capture on Raspberry Pi Pico (MicroPython).

Waits for the first rising edge on RX_PIN, then records alternating HIGH/LOW
pulse durations for CAPTURE_S seconds and prints them as
`[high1, low1, high2, low2, ...]`. Durations are in microseconds.

Wiring: RX DATA -> GP14, 3V3/5V + common GND, 17.3 cm antenna.
"""
import array
import time
from machine import Pin

RX_PIN = 14
CAPTURE_S = 3
MAX_EDGES = 8192   # ~32 KB; plenty for a few seconds of 433 MHz traffic


rx = Pin(RX_PIN, Pin.IN)
led = Pin("LED", Pin.OUT, value=0)   # mirrors RX line (works on Pico and Pico W)
edges = array.array('I', [0] * MAX_EDGES)
count = 0
started = False
last_us = 0


def on_edge(pin):
    global count, started, last_us
    now = time.ticks_us()
    level = pin.value()
    led.value(level)
    if not started:
        if level == 1:              # first rising edge — start the clock
            started = True
            last_us = now
        return
    if count < MAX_EDGES:
        edges[count] = time.ticks_diff(now, last_us)
        count += 1
    last_us = now


rx.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=on_edge)

print("rf433 raw: waiting for first signal on GP{} ...".format(RX_PIN))
while not started:
    time.sleep_ms(1)

print("capturing for {} s ...".format(CAPTURE_S))
time.sleep(CAPTURE_S)

rx.irq(handler=None)

print("captured {} edges (us):".format(count))
print(list(edges[:count]))
