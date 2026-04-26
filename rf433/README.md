# rf433

Python library for sending and receiving 433 MHz signals on a Raspberry Pi
using cheap ASK/OOK modules (FS1000A transmitter, XY-MK-5V / RXB6 receiver).

## Hardware

- Transmitter `DATA` -> any GPIO pin (default: BCM 17)
- Receiver `DATA` -> any GPIO pin (default: BCM 27)
- 5 V to both modules' VCC, common GND
- Antenna: 17.3 cm of straight wire on each module

## Install

```
pip install -r requirements.txt
```

## Usage

```python
from rf433 import Transmitter, Receiver

tx = Transmitter(pin=17)
tx.send(0xABCDEF, bits=24, repeats=8)

rx = Receiver(pin=27)
for code, bits, pulse_us in rx.listen():
    print(f"{code:0{bits}b} ({bits} bits, T={pulse_us} us)")
```

See `examples/` for runnable scripts.
