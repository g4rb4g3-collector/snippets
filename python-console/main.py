import sys


def read_key():
    """Read a single keypress, returning a normalized token.

    Returns one of: 'UP', 'DOWN', 'ENTER', a single character, or '' on EOF.
    """
    if sys.platform == "win32":
        import msvcrt

        ch = msvcrt.getch()
        if ch in (b"\x00", b"\xe0"):
            ch2 = msvcrt.getch()
            return {b"H": "UP", b"P": "DOWN"}.get(ch2, "")
        if ch in (b"\r", b"\n"):
            return "ENTER"
        try:
            return ch.decode("utf-8", errors="ignore")
        except Exception:
            return ""

    import termios
    import tty

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
        if ch == "\x1b":
            seq = sys.stdin.read(2)
            if seq == "[A":
                return "UP"
            if seq == "[B":
                return "DOWN"
            return ""
        if ch in ("\r", "\n"):
            return "ENTER"
        if ch == "\x03":
            raise KeyboardInterrupt
        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def render(options, selected):
    sys.stdout.write("\x1b[2J\x1b[H")
    sys.stdout.write("select mode:\n")
    for i, label in enumerate(options):
        line = f"[{i + 1}] {label}"
        if i == selected:
            sys.stdout.write(f"\x1b[7m{line}\x1b[0m\n")
        else:
            sys.stdout.write(f"{line}\n")
    sys.stdout.flush()


def select(options):
    selected = 0
    while True:
        render(options, selected)
        key = read_key()
        if key == "UP":
            selected = (selected - 1) % len(options)
        elif key == "DOWN":
            selected = (selected + 1) % len(options)
        elif key.isdigit() and 1 <= int(key) <= len(options):
            selected = int(key) - 1
        elif key == "ENTER":
            sys.stdout.write("\x1b[2J\x1b[H")
            sys.stdout.flush()
            return options[selected]


def main():
    options = ["mode1", "mode2", "mode3"]
    try:
        choice = select(options)
    except KeyboardInterrupt:
        sys.stdout.write("\n")
        return
    print(f"selected: {choice}")


if __name__ == "__main__":
    main()
