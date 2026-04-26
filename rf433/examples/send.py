"""Transmit a 24-bit code on GPIO 17."""
import argparse

from rf433 import Transmitter


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("code", type=lambda v: int(v, 0), help="code, e.g. 0xABCDEF")
    parser.add_argument("--pin", type=int, default=17)
    parser.add_argument("--bits", type=int, default=24)
    parser.add_argument("--repeats", type=int, default=8)
    args = parser.parse_args()

    tx = Transmitter(pin=args.pin)
    try:
        tx.send(args.code, bits=args.bits, repeats=args.repeats)
        print(f"sent 0x{args.code:X} ({args.bits} bits, {args.repeats}x)")
    finally:
        tx.close()


if __name__ == "__main__":
    main()
