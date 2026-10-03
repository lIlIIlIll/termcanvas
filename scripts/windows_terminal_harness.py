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


def check_message_pipe(binary: Path, environment: dict[str, str], timeout: float):
    """A two-byte native read must retain ERROR_MORE_DATA message prefixes."""
    import ctypes
    from ctypes import wintypes
    import msvcrt
    import os
    import subprocess
    import uuid

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateNamedPipeW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                      wintypes.DWORD, wintypes.DWORD, wintypes.DWORD,
                                      wintypes.DWORD, wintypes.LPVOID]
    kernel.CreateNamedPipeW.restype = wintypes.HANDLE
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                 wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.ConnectNamedPipe.argtypes = [wintypes.HANDLE, wintypes.LPVOID]
    kernel.WriteFile.argtypes = [wintypes.HANDLE, wintypes.LPCVOID, wintypes.DWORD,
                                ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    name = "\\\\.\\pipe\\termcanvas-input-" + uuid.uuid4().hex
    invalid = ctypes.c_void_p(-1).value
    server = kernel.CreateNamedPipeW(name, 1, 4 | 2, 1, 4096, 4096, 0, None)
    if server == invalid:
        raise ctypes.WinError(ctypes.get_last_error())
    writer = invalid
    stream = None
    try:
        writer = kernel.CreateFileW(name, 0x40000000, 0, None, 3, 0, None)
        if writer == invalid:
            raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.ConnectNamedPipe(server, None) and ctypes.get_last_error() != 535:
            raise ctypes.WinError(ctypes.get_last_error())
        payload = "A界😀Z".encode("utf-8")
        written = wintypes.DWORD()
        if not kernel.WriteFile(writer, payload, len(payload), ctypes.byref(written), None):
            raise ctypes.WinError(ctypes.get_last_error())
        if written.value != len(payload):
            raise AssertionError("message pipe fixture did not write its complete payload")
        descriptor = msvcrt.open_osfhandle(server, os.O_RDONLY | os.O_BINARY)
        server = invalid  # descriptor owns the server handle from this point.
        stream = os.fdopen(descriptor, "rb", buffering=0)
        result = subprocess.run([str(binary), "redirected"], stdin=stream, env=environment,
                                capture_output=True, timeout=timeout, check=True)
        if b"NATIVE_REDIRECTED_OK" not in result.stdout:
            raise AssertionError("message-mode stdin lost a partial ReadFile prefix")
    finally:
        if stream is not None:
            stream.close()
        if server != invalid:
            kernel.CloseHandle(server)
        if writer != invalid:
            kernel.CloseHandle(writer)


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
        self.process.write(data.decode("utf-8"))

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
