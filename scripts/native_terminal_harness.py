#!/usr/bin/env python3
"""Repository-owned native PTY checks for terminal mode, resize, wake and cleanup.

POSIX PTYs run on Linux/macOS; Windows uses native ConPTY via pywinpty 3.0.5.
"""
from __future__ import annotations

import argparse
import errno
import json
import os
from pathlib import Path
import platform
import selectors
import signal
import subprocess
import sys
import tempfile
import time

from native_sdk import sdk_environment, verify_sdk

ROOT = Path(__file__).resolve().parents[1]


class PtySession:
    def __init__(self, binary: Path, mode: str, environment: dict[str, str], timeout: float):
        import fcntl
        import pty
        import struct
        import termios
        self.termios = termios
        self.fcntl = fcntl
        self.struct = struct
        self.timeout = timeout
        self.master, self.slave = pty.openpty()
        self.selector = selectors.DefaultSelector()
        self.process = None
        self.output = bytearray()
        try:
            self.original = termios.tcgetattr(self.slave)
            self.resize(80, 24)
            env = environment.copy()
            env.update({"TERM": "xterm-256color", "COLORTERM": "truecolor"})
            self.process = subprocess.Popen(
                [str(binary), mode], stdin=self.slave, stdout=self.slave, stderr=self.slave,
                env=env, start_new_session=True, close_fds=True
            )
            self.selector.register(self.master, selectors.EVENT_READ)
        except BaseException:
            self.close()
            raise

    def resize(self, width: int, height: int):
        self.fcntl.ioctl(self.slave, self.termios.TIOCSWINSZ,
                         self.struct.pack("HHHH", height, width, 0, 0))
        if self.process is not None and self.process.poll() is None:
            os.kill(self.process.pid, signal.SIGWINCH)

    def pump(self, timeout: float):
        for key, _ in self.selector.select(timeout):
            try:
                data = os.read(key.fd, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    return
                raise
            self.output.extend(data)

    def wait_for(self, marker: bytes, start: int = 0):
        deadline = time.monotonic() + self.timeout
        while marker not in self.output[start:]:
            self.pump(min(0.05, max(0, deadline - time.monotonic())))
            if time.monotonic() >= deadline:
                raise AssertionError(f"timeout waiting for {marker!r}; output={bytes(self.output[-1200:])!r}")
            if self.process.poll() is not None and marker not in self.output[start:]:
                self.pump(0)
                if marker not in self.output[start:]:
                    raise AssertionError(f"probe exited {self.process.returncode} before {marker!r}")

    def send(self, data: bytes):
        os.write(self.master, data)

    def assert_raw(self):
        current = self.termios.tcgetattr(self.slave)
        flags = self.termios.ECHO | self.termios.ICANON
        if current[3] & flags:
            raise AssertionError("application did not disable terminal echo and canonical input")

    def assert_closed(self, expected_exit: int):
        deadline = time.monotonic() + self.timeout
        while self.process.poll() is None and time.monotonic() < deadline:
            self.pump(0.05)
        if self.process.poll() is None:
            raise AssertionError("probe failed to exit")
        self.pump(0)
        if self.process.returncode != expected_exit:
            raise AssertionError(f"expected exit {expected_exit}; got {self.process.returncode}")
        if self.termios.tcgetattr(self.slave) != self.original:
            raise AssertionError("terminal attributes were not restored exactly")
        if b"\x1b[?1049h" not in self.output or b"\x1b[?1049l" not in self.output:
            raise AssertionError("alternate screen was not entered and restored")
        if b"\x1b[?25h" not in self.output:
            raise AssertionError("cursor visibility was not restored")

    def close(self):
        if self.process is not None and self.process.poll() is None:
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            self.process.wait(timeout=5)
        self.selector.close()
        os.close(self.master)
        os.close(self.slave)


def run_checks(binary: Path, environment: dict[str, str], timeout: float,
               session_type=None) -> list[dict]:
    if session_type is None:
        if platform.system() == "Windows":
            from windows_terminal_harness import ConPtySession
            session_type = ConPtySession
        else:
            session_type = PtySession
    results = []
    for mode in ("input", "external", "exception"):
        session = session_type(binary, mode, environment, timeout)
        try:
            session.wait_for(b"NATIVE_READY")
            session.assert_raw()
            if mode == "input":
                session.send(b"x")
                session.wait_for(b"NATIVE_INPUT_OK")
                session.resize(93, 31)
                session.wait_for(b"NATIVE_RESIZE_93x31")
                session.send(b"q")
                session.assert_closed(0)
                results.append({"scenario": mode, "passed": True, "resize": [93, 31]})
            elif mode == "external":
                start = len(session.output)
                written = time.monotonic()
                session.send(b"w")
                session.wait_for(b"NATIVE_AWAKE", start)
                elapsed = time.monotonic() - written
                # The probe has no ticks/resize deadline and a five-second
                # fallback sleep. This needs a real wake source to pass.
                if elapsed >= 3:
                    raise AssertionError(f"idle external event took {elapsed:.3f}s without timely wake")
                session.send(b"q")
                session.assert_closed(0)
                results.append({"scenario": mode, "passed": True, "wake_seconds": elapsed})
            else:
                session.send(b"x")
                session.wait_for(b"NATIVE_EXPECTED_EXCEPTION")
                session.assert_closed(17)
                results.append({"scenario": mode, "passed": True, "expected_exit": 17})
        finally:
            session.close()
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, help="prebuilt tests/fixtures/native_terminal binary")
    parser.add_argument("--target-dir", type=Path, help="isolated cjpm target directory")
    parser.add_argument("--output", type=Path, help="JSON report path")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()
    if platform.system() not in ("Linux", "Darwin", "Windows"):
        parser.error("native terminal harness supports Linux, macOS and Windows")
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    windows = platform.system() == "Windows"
    report = {"platform": platform.system(), "passed": False, "scenarios": [],
              "transport": "ConPTY" if windows else "POSIX PTY",
              "restore_checks": ["console input/output modes", "cursor size/visibility"] if windows
              else ["termios", "alternate-screen exit", "cursor visibility"]}
    try:
        root, env, _ = sdk_environment(os.environ.get("CANGJIE_SDK_ROOT", ""))
        verify_sdk(root, env)
        with tempfile.TemporaryDirectory(prefix="termcanvas-native-pty-") as temporary:
            binary = args.binary
            if binary is None:
                target = args.target_dir.resolve() if args.target_dir else Path(temporary) / "target"
                suffix = ".exe" if windows else ""
                subprocess.run([str(root / f"tools/bin/cjpm{suffix}"), "build", "--target-dir", str(target)],
                               cwd=ROOT / "tests/fixtures/native_terminal", env=env, check=True, timeout=300)
                binary = target / f"release/bin/main{suffix}"
            report["scenarios"] = run_checks(binary.resolve(), env, args.timeout)
        report["passed"] = True
    except Exception as error:
        # Include backend-specific errors (for example pywinpty.WinptyError)
        # in the same failing report as SDK, assertion and process failures.
        report["error"] = f"{type(error).__name__}: {error}"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
