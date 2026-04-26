"""Print every code received on GPIO 27. Ctrl-C to stop."""
import argparse

from rf433 import Receiver


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pin", type=int, default=27)
    args = parser.parse_args()

    rx = Receiver(pin=args.pin)
    try:
        for code, bits, pulse_us in rx.listen():
            print(f"0x{code:0{(bits + 3) // 4}X}  bits={bits}  pulse={pulse_us}us")
    except KeyboardInterrupt:
        pass
    finally:
        rx.close()


if __name__ == "__main__":
    main()
