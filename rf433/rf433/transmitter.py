import time

import RPi.GPIO as GPIO

from .protocol import Protocol, Pulse, PROTOCOL_1


class Transmitter:
    def __init__(self, pin: int, protocol: Protocol = PROTOCOL_1):
        self.pin = pin
        self.protocol = protocol
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)

    def send(self, code: int, bits: int = 24, repeats: int = 8) -> None:
        p = self.protocol
        frame = [(code >> (bits - 1 - i)) & 1 for i in range(bits)]
        for _ in range(repeats):
            for bit in frame:
                self._pulse(p.one if bit else p.zero)
            self._pulse(p.sync)

    def close(self) -> None:
        GPIO.output(self.pin, GPIO.LOW)
        GPIO.cleanup(self.pin)

    def _pulse(self, pulse: Pulse) -> None:
        unit = self.protocol.pulse_us / 1_000_000
        GPIO.output(self.pin, GPIO.HIGH)
        _busy_wait(unit * pulse.high)
        GPIO.output(self.pin, GPIO.LOW)
        _busy_wait(unit * pulse.low)


def _busy_wait(seconds: float) -> None:
    # time.sleep() is too coarse for sub-millisecond pulse timing.
    end = time.perf_counter() + seconds
    while time.perf_counter() < end:
        pass
