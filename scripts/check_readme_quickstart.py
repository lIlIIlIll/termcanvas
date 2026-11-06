#!/usr/bin/env python3
"""Compile and exercise the README quickstart in a real POSIX PTY.

The README is the source of the program.  This check verifies terminal output,
timer-driven progress, keyboard exit and terminal restoration; it does not
replace a real terminal-emulator screenshot or visual review.
"""
from __future__ import annotations

import codecs
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import tempfile
import threading
import time
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
START = "<!-- termcanvas-quickstart:start -->"
END = "<!-- termcanvas-quickstart:end -->"
MANIFEST_START = "<!-- termcanvas-quickstart-manifest:start -->"
MANIFEST_END = "<!-- termcanvas-quickstart-manifest:end -->"


def extract_quickstart(readme: str) -> str:
    if readme.count(START) != 1 or readme.count(END) != 1:
        raise ValueError("README must contain exactly one quickstart marker pair")
    start, end = readme.index(START) + len(START), readme.index(END)
    if end <= start:
        raise ValueError("README quickstart markers are reversed")
    blocks = re.findall(r"```cangjie\s*\n(.*?)\n```", readme[start:end], re.DOTALL)
    if len(blocks) != 1:
        raise ValueError("README quickstart must contain exactly one Cangjie block")
    return blocks[0] + "\n"


def extract_manifest(readme: str, core_path: str) -> str:
    if readme.count(MANIFEST_START) != 1 or readme.count(MANIFEST_END) != 1:
        raise ValueError("README must contain exactly one manifest marker pair")
    start, end = readme.index(MANIFEST_START) + len(MANIFEST_START), readme.index(MANIFEST_END)
    if end <= start:
        raise ValueError("README manifest markers are reversed")
    blocks = re.findall(r"```toml\s*\n(.*?)\n```", readme[start:end], re.DOTALL)
    if len(blocks) != 1:
        raise ValueError("README quickstart must contain exactly one TOML block")
    manifest = blocks[0] + "\n"
    original = 'path = "../packages/core"'
    if manifest.count(original) != 1:
        raise ValueError("README manifest must contain exactly one core path dependency")
    escaped = core_path.replace("\\", "\\\\").replace('"', '\\"')
    return manifest.replace(original, f'path = "{escaped}"', 1)


class Screen:
    """Small streaming VT screen used only to observe the example's text."""

    def __init__(self, columns: int = 80, rows: int = 24):
        self.columns, self.rows = columns, rows
        self.cells = [[" "] * columns for _ in range(rows)]
        self.x = self.y = 0
        self.pending = ""
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def feed(self, data: bytes) -> None:
        self.pending += self.decoder.decode(data)
        text = self.pending
        pos = 0
        while pos < len(text):
            char = text[pos]
            if char == "\x1b":
                if pos + 1 >= len(text):
                    break
                if text[pos + 1] == "[":
                    end = pos + 2
                    while end < len(text) and not ("@" <= text[end] <= "~"):
                        end += 1
                    if end == len(text):
                        break
                    params, command = text[pos + 2:end], text[end]
                    if command in ("H", "f"):
                        parts = params.split(";")
                        if all(not p or p.isdigit() for p in parts):
                            self.y = max(0, int(parts[0] or 1) - 1)
                            self.x = max(0, int(parts[1] or 1) - 1) if len(parts) > 1 else 0
                    elif command == "J" and params == "2":
                        self.cells = [[" "] * self.columns for _ in range(self.rows)]
                    pos = end + 1
                    continue
                if text[pos + 1] == "]":
                    bell = text.find("\x07", pos + 2)
                    st = text.find("\x1b\\", pos + 2)
                    ends = [(bell, 1), (st, 2)]
                    ends = [(index, length) for index, length in ends if index >= 0]
                    if not ends:
                        break
                    index, length = min(ends)
                    pos = index + length
                    continue
                pos += 2
                continue
            if char == "\r":
                self.x = 0
            elif char == "\n":
                self.y += 1
            elif char == "\b":
                self.x = max(0, self.x - 1)
            elif ord(char) >= 32 and char != "\x7f":
                width = 0 if unicodedata.combining(char) else (
                    2 if unicodedata.east_asian_width(char) in ("W", "F") else 1
                )
                if width and 0 <= self.y < self.rows and 0 <= self.x < self.columns:
                    self.cells[self.y][self.x] = char
                    if width == 2 and self.x + 1 < self.columns:
                        self.cells[self.y][self.x + 1] = " "
                self.x += width
            pos += 1
        self.pending = text[pos:]

    def progress(self) -> set[str]:
        return set(re.findall(r"\b\d+(?:\.\d+)?%", "\n".join(map("".join, self.cells))))


def exercise(binary: Path, project: Path, timeout: float = 10) -> None:
    import fcntl
    import pty
    import struct
    import termios

    master, slave = pty.openpty()
    selector = selectors.DefaultSelector()
    process = None
    exit_read, exit_write = os.pipe()
    original = termios.tcgetattr(slave)
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        env = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor")
        process = subprocess.Popen([str(ROOT / "scripts/cangjie_cmd.sh"), str(project), str(binary)],
                                   stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True)
        def report_exit() -> None:
            process.wait()
            try:
                os.write(exit_write, b"x")
            except OSError:
                pass
        threading.Thread(target=report_exit, daemon=True).start()
        selector.register(master, selectors.EVENT_READ, "terminal")
        selector.register(exit_read, selectors.EVENT_READ, "exit")
        screen, observed = Screen(), set()
        output = bytearray()
        deadline = time.monotonic() + timeout
        while len(observed) < 2:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f"progress did not change; observed {sorted(observed)}")
            events = selector.select(remaining)
            if not events:
                raise AssertionError(f"progress did not change; observed {sorted(observed)}")
            for key, _ in events:
                if key.data == "exit":
                    raise AssertionError(f"quickstart exited with status {process.returncode} before progress changed; "
                                         f"output: {bytes(output[-1000:])!r}")
                try:
                    chunk = os.read(key.fd, 65536)
                except OSError as error:
                    raise AssertionError("quickstart exited before progress changed") from error
                if not chunk:
                    raise AssertionError("quickstart exited before progress changed")
                output.extend(chunk)
                screen.feed(chunk)
                observed.update(screen.progress())
        os.write(master, b"q")
        process.wait(timeout=timeout)
        if process.returncode != 0:
            raise AssertionError(f"quickstart exited with status {process.returncode}")
        if termios.tcgetattr(slave) != original:
            raise AssertionError("quickstart did not restore terminal attributes")
        print(f"README quickstart: observed {len(observed)} progress values; q exited and restored terminal")
    finally:
        if process is not None and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
        selector.close()
        os.close(exit_read)
        os.close(exit_write)
        os.close(master)
        os.close(slave)


def main() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    source = extract_quickstart(readme)
    with tempfile.TemporaryDirectory(prefix="termcanvas-readme-") as directory:
        project = Path(directory)
        (project / "src").mkdir()
        (project / "src/main.cj").write_text(source, encoding="utf-8")
        # The source checkout is a path dependency; no registry support is assumed.
        manifest = extract_manifest(readme, str(ROOT / "packages/core"))
        (project / "cjpm.toml").write_text(manifest, encoding="utf-8")
        target = project / "target"
        subprocess.run([str(ROOT / "scripts/cangjie_cmd.sh"), str(project), "cjpm", "build",
                        "--target-dir", str(target)], check=True)
        exercise(target / "release/bin/main", project)


if __name__ == "__main__":
    main()
