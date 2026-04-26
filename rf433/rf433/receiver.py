import time
from typing import Iterator, Tuple

import RPi.GPIO as GPIO

from .protocol import Protocol, PROTOCOL_1

_MAX_CHANGES = 67  # sync + 32 bits * 2 edges, with headroom
_TOLERANCE = 60    # percent


class Receiver:
    def __init__(self, pin: int, protocol: Protocol = PROTOCOL_1):
        self.pin = pin
        self.protocol = protocol
        self._timings = [0] * _MAX_CHANGES
        self._change_count = 0
        self._last_us = 0
        self._repeat_count = 0
        self._last_code = (0, 0, 0)
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(pin, GPIO.IN)

    def listen(self, poll_interval: float = 0.001) -> Iterator[Tuple[int, int, int]]:
        """Yield `(code, bits, pulse_us)` for every distinct frame received."""
        GPIO.add_event_detect(self.pin, GPIO.BOTH, callback=self._on_edge)
        try:
            while True:
                if self._last_code != (0, 0, 0):
                    yield self._last_code
                    self._last_code = (0, 0, 0)
                time.sleep(poll_interval)
        finally:
            GPIO.remove_event_detect(self.pin)

    def close(self) -> None:
        GPIO.cleanup(self.pin)

    def _on_edge(self, _channel: int) -> None:
        now = time.perf_counter_ns() // 1000
        duration = now - self._last_us
        self._last_us = now

        if duration > self.protocol.pulse_us * self.protocol.sync.low * 0.7:
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

    def _decode(self, change_count: int) -> None:
        p = self.protocol
        delay = self._timings[0] // p.sync.low
        if delay == 0:
            return
        delay_tolerance = delay * _TOLERANCE // 100
        code = 0
        bits = 0
        for i in range(1, change_count - 1, 2):
            high = self._timings[i]
            low = self._timings[i + 1]
            if (abs(high - delay * p.one.high) < delay_tolerance
                    and abs(low - delay * p.one.low) < delay_tolerance):
                code = (code << 1) | 1
                bits += 1
            elif (abs(high - delay * p.zero.high) < delay_tolerance
                    and abs(low - delay * p.zero.low) < delay_tolerance):
                code = code << 1
                bits += 1
            else:
                return
        if bits >= 6:
            self._last_code = (code, bits, delay)
