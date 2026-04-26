"""rf433 — raw 433 MHz pulse capture on Raspberry Pi Pico (MicroPython).

Waits for the first rising edge on RX_PIN, then records alternating HIGH/LOW
pulse durations until a LOW pulse of at least GAP_US microseconds is seen
(end-of-frame gap). Prints the result as `[high1, low1, high2, low2, ...]`,
durations in microseconds.

Wiring: RX DATA -> GP14, 3V3/5V + common GND, 17.3 cm antenna.
"""
import array
import time
from machine import Pin

RX_PIN = 14
GAP_US = 2000        # stop after a LOW gap this long
MAX_EDGES = 8192     # ~32 KB; safety cap


rx = Pin(RX_PIN, Pin.IN)
led = Pin("LED", Pin.OUT, value=0)   # mirrors RX line (works on Pico and Pico W)
edges = array.array('I', [0] * MAX_EDGES)
count = 0
started = False
done = False
last_us = 0


def on_edge(pin):
    global count, started, done, last_us
    now = time.ticks_us()
    level = pin.value()
    led.value(level)
    if not started:
        if level == 1:              # first rising edge — start the clock
            started = True
            last_us = now
        return
    if done:
        return
    duration = time.ticks_diff(now, last_us)
    last_us = now
    if count < MAX_EDGES:
        edges[count] = duration
        count += 1
    # Just-recorded entry sits at index (count - 1); odd index == LOW pulse.
    if (count & 1) == 0 and duration >= GAP_US:
        count -= 1                  # drop the trailing gap
        done = True


rx.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=on_edge)

print("rf433 raw: waiting for first signal on GP{} ...".format(RX_PIN))
while not started:
    time.sleep_ms(1)

print("capturing until LOW >= {} us ...".format(GAP_US))
while not done and count < MAX_EDGES:
    time.sleep_ms(1)

rx.irq(handler=None)

print("captured {} edges (us):".format(count))
print(list(edges[:count]))
