"""ConPTY transport for native_terminal_harness (pywinpty 3.0.5).

The child observes its own Console API state and handled events. The transport
provides actual native input, resize, process status and bounded output draining.
"""
from __future__ import annotations

from importlib.metadata import version
from pathlib import Path
import selectors
import signal
import tempfile
import time


class ConPtySession:
    def __init__(self, binary: Path, mode: str, environment: dict[str, str], timeout: float):
        try:
            if version("pywinpty") != "3.0.5":
                raise ValueError("Windows harness requires pywinpty==3.0.5")
            from winpty import PtyProcess
            from winpty.enums import Backend
        except ImportError as error:
            raise ValueError("install the Windows harness dependency: pip install pywinpty==3.0.5") from error
        self.timeout = timeout
        self.output = bytearray()
        self.terminal_output = bytearray()
        self.seen = set()
        self.process = None
        self.selector = selectors.DefaultSelector()
        self.temporary = tempfile.TemporaryDirectory(prefix="termcanvas-conpty-")
        self.observations = Path(self.temporary.name)
        try:
            env = environment.copy()
            env.update({"TERM": "xterm-256color", "COLORTERM": "truecolor"})
            # PtyProcess uses `backend or env`: integer ConPTY=0 would permit an
            # ambient PYWINPTY_BACKEND to override it. String "0" forces ConPTY.
            self.process = PtyProcess.spawn(
                [str(binary), mode, str(self.observations)], env=env,
                dimensions=(24, 80), backend=str(Backend.ConPTY)
            )
            # pywinpty 3.0.5 exposes a socket-backed fileno (its upstream
            # selector tests use this). Read bytes to avoid decoder blocking
            # at a partial UTF-8 sequence inside PtyProcess.read().
            self.selector.register(self.process.fileobj, selectors.EVENT_READ)
        except BaseException:
            self.close()
            raise

    def resize(self, width: int, height: int):
        self.process.setwinsize(height, width)

    def pump(self, timeout: float):
        if not self.selector.get_map():
            # Winsock select rejects three empty socket lists after EOF.
            time.sleep(timeout)
            ready = []
        else:
            ready = self.selector.select(timeout)
        for key, _ in ready:
            data = key.fileobj.recv(65536)
            if data:
                self.terminal_output.extend(data)
            else:
                self.selector.unregister(key.fileobj)
        for marker in sorted(self.observations.iterdir()):
            if marker.name not in self.seen:
                self.seen.add(marker.name)
                self.output.extend(marker.name.encode("ascii") + b"\n")

    def alive(self):
        # Unlike PtyProcess.isalive(), this does not mark the socket wrapper
        # closed before close() has actually released its resources.
        return self.process.pty.isalive()

    def wait_for(self, marker: bytes, start: int = 0):
        deadline = time.monotonic() + self.timeout
        while marker not in self.output[start:]:
            self.pump(min(0.02, max(0, deadline - time.monotonic())))
            if marker in self.output[start:]:
                return
            if not self.alive() or time.monotonic() >= deadline:
                raise AssertionError(
                    f"ConPTY probe missing {marker!r}; exit={self.process.exitstatus}; "
                    f"observations={bytes(self.output)!r}; output={bytes(self.terminal_output[-1200:])!r}"
                )

    def send(self, data: bytes):
        self.process.write(data.decode("ascii"))

    def assert_raw(self):
        self.wait_for(b"NATIVE_RAW_OK")

    def assert_closed(self, expected_exit: int):
        self.wait_for(b"NATIVE_CONSOLE_RESTORED")
        deadline = time.monotonic() + self.timeout
        while self.alive() and time.monotonic() < deadline:
            self.pump(0.02)
        if self.alive():
            raise AssertionError("ConPTY probe failed to exit")
        if self.process.exitstatus != expected_exit:
            raise AssertionError(f"expected exit {expected_exit}; got {self.process.exitstatus}")

    def close(self):
        try:
            if self.process is not None:
                try:
                    if self.alive():
                        # On Windows SIGTERM maps to TerminateProcess. The probe
                        # has no subprocesses; its producer is a thread.
                        try:
                            self.process.kill(signal.SIGTERM)
                        except OSError:
                            if self.alive():
                                raise
                finally:
                    self.process.close(force=True)
        finally:
            self.selector.close()
            self.temporary.cleanup()
