"""rf433 — single-file 433 MHz ASK/OOK helper for Raspberry Pi Pico (MicroPython).

Drop on the Pico as `main.py`. Edit the CONFIG block below to switch between
"send" and "recv" modes. Wiring:

    TX DATA -> GP15, RX DATA -> GP14, 3V3/5V + common GND, 17.3 cm antenna.
"""
from machine import Pin
import time

# --- CONFIG -----------------------------------------------------------------
MODE = "send"          # "send" or "recv"
TX_PIN = 15
RX_PIN = 14
SEND_CODE = 0xABCDEF
SEND_BITS = 24
SEND_REPEATS = 8
SEND_INTERVAL_S = 2    # delay between transmissions in send mode
# ---------------------------------------------------------------------------

# PT2262 / EV1527 timing — covers most cheap 433 MHz remotes.
PULSE_US = 350
SYNC = (1, 31)
ZERO = (1, 3)
ONE = (3, 1)


def _busy_wait_us(us):
    end = time.ticks_add(time.ticks_us(), us)
    while time.ticks_diff(end, time.ticks_us()) > 0:
        pass


class Transmitter:
    def __init__(self, pin):
        self.pin = Pin(pin, Pin.OUT, value=0)

    def send(self, code, bits=24, repeats=8):
        for _ in range(repeats):
            for i in range(bits):
                bit = (code >> (bits - 1 - i)) & 1
                self._pulse(ONE if bit else ZERO)
            self._pulse(SYNC)
        self.pin.value(0)

    def _pulse(self, pulse):
        high, low = pulse
        self.pin.value(1)
        _busy_wait_us(PULSE_US * high)
        self.pin.value(0)
        _busy_wait_us(PULSE_US * low)


_MAX_CHANGES = 67
_TOLERANCE = 60


class Receiver:
    def __init__(self, pin):
        self.pin = Pin(pin, Pin.IN)
        self._timings = [0] * _MAX_CHANGES
        self._change_count = 0
        self._last_us = 0
        self._repeat_count = 0
        self._code = 0
        self._bits = 0
        self._delay = 0
        self._ready = False
        self.pin.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=self._on_edge)

    def poll(self):
        if not self._ready:
            return None
        result = (self._code, self._bits, self._delay)
        self._ready = False
        return result

    def _on_edge(self, _pin):
        now = time.ticks_us()
        duration = time.ticks_diff(now, self._last_us)
        self._last_us = now

        if duration > PULSE_US * SYNC[1] * 0.7:
            if abs(duration - self._timings[0]) < 200:
                self._repeat_count += 1
                if self._repeat_count == 2:
                    self._decode(self._change_count)
                    self._repeat_count = 0
            self._change_count = 0

        if self._change_count >= _MAX_CHANGES:
            self._change_count = 0
            self._repeat_count = 0

        self._timings[self._change_count] = duration
        self._change_count += 1

    def _decode(self, change_count):
        delay = self._timings[0] // SYNC[1]
        if delay == 0:
            return
        tol = delay * _TOLERANCE // 100
        code = 0
        bits = 0
        for i in range(1, change_count - 1, 2):
            high = self._timings[i]
            low = self._timings[i + 1]
            if (abs(high - delay * ONE[0]) < tol
                    and abs(low - delay * ONE[1]) < tol):
                code = (code << 1) | 1
                bits += 1
            elif (abs(high - delay * ZERO[0]) < tol
                    and abs(low - delay * ZERO[1]) < tol):
                code = code << 1
                bits += 1
            else:
                return
        if bits >= 6:
            self._code = code
            self._bits = bits
            self._delay = delay
            self._ready = True


def run_send():
    tx = Transmitter(TX_PIN)
    print("rf433 send: code=0x{:X} bits={} repeats={}".format(
        SEND_CODE, SEND_BITS, SEND_REPEATS))
    while True:
        tx.send(SEND_CODE, SEND_BITS, SEND_REPEATS)
        print("sent 0x{:X}".format(SEND_CODE))
        time.sleep(SEND_INTERVAL_S)


def run_recv():
    rx = Receiver(RX_PIN)
    print("rf433 recv: listening on GP{}".format(RX_PIN))
    while True:
        result = rx.poll()
        if result:
            code, bits, pulse_us = result
            print("0x{:X}  bits={}  pulse={}us".format(code, bits, pulse_us))
        time.sleep_ms(1)


if MODE == "send":
    run_send()
elif MODE == "recv":
    run_recv()
else:
    raise ValueError("MODE must be 'send' or 'recv', got {!r}".format(MODE))
