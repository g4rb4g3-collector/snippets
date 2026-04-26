from dataclasses import dataclass


@dataclass(frozen=True)
class Pulse:
    high: int
    low: int


@dataclass(frozen=True)
class Protocol:
    """Timing for an ASK/OOK protocol, expressed as multiples of `pulse_us`."""

    pulse_us: int
    sync: Pulse
    zero: Pulse
    one: Pulse


# PT2262 / EV1527 family — works for the vast majority of cheap 433 MHz remotes.
PROTOCOL_1 = Protocol(
    pulse_us=350,
    sync=Pulse(high=1, low=31),
    zero=Pulse(high=1, low=3),
    one=Pulse(high=3, low=1),
)
