"""rf433 — single-file 433 MHz ASK/OOK helper for Raspberry Pi.

Usage:
    sudo python main.py send 0xABCDEF [--pin 17] [--bits 24] [--repeats 8]
    sudo python main.py recv         [--pin 27]

Wiring: TX DATA -> BCM 17, RX DATA -> BCM 27, 5V + common GND, 17.3 cm antenna.
"""
import argparse
import time
from dataclasses import dataclass
from typing import Iterator, Tuple

import RPi.GPIO as GPIO


@dataclass(frozen=True)
class Pulse:
    high: int
    low: int


@dataclass(frozen=True)
class Protocol:
    pulse_us: int
    sync: Pulse
    zero: Pulse
    one: Pulse


# PT2262 / EV1527 — covers most cheap 433 MHz remotes.
PROTOCOL_1 = Protocol(
    pulse_us=350,
    sync=Pulse(high=1, low=31),
    zero=Pulse(high=1, low=3),
    one=Pulse(high=3, low=1),
)


def _busy_wait(seconds: float) -> None:
    end = time.perf_counter() + seconds
    while time.perf_counter() < end:
        pass


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


_MAX_CHANGES = 67
_TOLERANCE = 60


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


def _cmd_send(args: argparse.Namespace) -> None:
    tx = Transmitter(pin=args.pin)
    try:
        tx.send(args.code, bits=args.bits, repeats=args.repeats)
        print(f"sent 0x{args.code:X} ({args.bits} bits, {args.repeats}x)")
    finally:
        tx.close()


def _cmd_recv(args: argparse.Namespace) -> None:
    rx = Receiver(pin=args.pin)
    try:
        for code, bits, pulse_us in rx.listen():
            print(f"0x{code:0{(bits + 3) // 4}X}  bits={bits}  pulse={pulse_us}us")
    except KeyboardInterrupt:
        pass
    finally:
        rx.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="433 MHz send/receive on Raspberry Pi.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("send", help="Transmit a code.")
    s.add_argument("code", type=lambda v: int(v, 0), help="code, e.g. 0xABCDEF")
    s.add_argument("--pin", type=int, default=17)
    s.add_argument("--bits", type=int, default=24)
    s.add_argument("--repeats", type=int, default=8)
    s.set_defaults(func=_cmd_send)

    r = sub.add_parser("recv", help="Print received codes (Ctrl-C to stop).")
    r.add_argument("--pin", type=int, default=27)
    r.set_defaults(func=_cmd_recv)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
