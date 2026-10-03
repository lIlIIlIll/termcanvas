"""Exercise the native fork/exec boundary without requiring the Cangjie SDK."""
import ctypes
import errno
import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time
import unittest


@unittest.skipIf(os.name == "nt", "POSIX native implementation")
class NativeSpawnTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="termcanvas-spawn-")
        cls.addClassCleanup(cls.directory.cleanup)
        library = Path(cls.directory.name) / "spawn.so"
        subprocess.run([os.environ.get("CC", "cc"), "-std=c11", "-O2", "-shared", "-fPIC",
                        "-Wall", "-Wextra", "-Werror", str(Path(__file__).with_name("spawn.c")),
                        "-o", str(library)], check=True)
        cls.library = ctypes.CDLL(str(library))
        cls.start = cls.library.termcanvas_spawn
        strings = ctypes.POINTER(ctypes.c_char_p)
        cls.start.argtypes = [strings, strings, ctypes.c_char_p] + [ctypes.c_int32] * 5 + [
            ctypes.POINTER(ctypes.c_int32), ctypes.c_int64]
        cls.start.restype = ctypes.c_int32
        cls.fcntl = cls.library.termcanvas_fcntl
        cls.fcntl.argtypes = [ctypes.c_int32] * 3
        cls.fcntl.restype = ctypes.c_int32
        cls.ioctl = cls.library.termcanvas_ioctl
        cls.ioctl.argtypes = [ctypes.c_int32, ctypes.c_uint64, ctypes.c_void_p]
        cls.ioctl.restype = ctypes.c_int32

    def test_fixed_arity_fcntl_sets_actual_nonblocking_and_cloexec_flags(self):
        import fcntl

        read_fd, write_fd = os.pipe()
        duplicate = -1
        try:
            # Reset Python's default CLOEXEC so the native wrapper must set it.
            os.set_inheritable(read_fd, True)
            flags = self.fcntl(read_fd, fcntl.F_GETFL, 0)
            self.assertGreaterEqual(flags, 0)
            self.assertEqual(self.fcntl(read_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK), 0)
            self.assertEqual(self.fcntl(read_fd, fcntl.F_SETFD, fcntl.FD_CLOEXEC), 0)
            self.assertTrue(fcntl.fcntl(read_fd, fcntl.F_GETFL) & os.O_NONBLOCK)
            self.assertTrue(fcntl.fcntl(read_fd, fcntl.F_GETFD) & fcntl.FD_CLOEXEC)
            with self.assertRaises(BlockingIOError):
                os.read(read_fd, 1)
            duplicate = self.fcntl(read_fd, fcntl.F_DUPFD, max(read_fd, write_fd) + 1)
            self.assertGreater(duplicate, max(read_fd, write_fd))
        finally:
            if duplicate >= 0:
                os.close(duplicate)
            os.close(read_fd)
            os.close(write_fd)

    def test_fixed_arity_ioctl_sets_and_gets_native_pty_size(self):
        import fcntl
        import struct
        import termios

        master, slave = os.openpty()
        try:
            requested = ctypes.create_string_buffer(struct.pack("HHHH", 31, 93, 0, 0))
            self.assertEqual(self.ioctl(master, termios.TIOCSWINSZ, requested), 0)
            actual = ctypes.create_string_buffer(8)
            self.assertEqual(self.ioctl(slave, termios.TIOCGWINSZ, actual), 0)
            self.assertEqual(struct.unpack("HHHH", actual.raw), (31, 93, 0, 0))
            self.assertEqual(fcntl.ioctl(slave, termios.TIOCGWINSZ, bytes(8)), actual.raw)
        finally:
            os.close(master)
            os.close(slave)

    def run_child(self, args, *, env=(), cwd="", terminal=False):
        pairs = [os.pipe() for _ in range(4)]
        stdin, stdout, stderr, startup = pairs
        master, slave = os.openpty() if terminal else (-1, -1)
        owned = {fd for pair in pairs for fd in pair}
        if terminal:
            owned.update((master, slave))
        pid = -1
        reaped = False
        try:
            arguments = (ctypes.c_char_p * (len(args) + 1))(*[s.encode() for s in args], None)
            environment = (ctypes.c_char_p * (len(env) + 1))(*[s.encode() for s in env], None)
            descriptors = (ctypes.c_int32 * len(owned))(*owned)
            pid = self.start(arguments, environment, cwd.encode(), slave if terminal else stdin[0],
                             slave if terminal else stdout[1], stderr[1], slave, startup[1],
                             descriptors, len(owned))
            self.assertGreater(pid, 0)
            reads = {master if terminal else stdout[0]: "stdout", stderr[0]: "stderr", startup[0]: "startup"}
            for fd in owned - reads.keys():
                os.close(fd)
            owned = set(reads)
            chunks = {name: bytearray() for name in reads.values()}
            deadline = time.monotonic() + 5
            with selectors.DefaultSelector() as poller:
                for fd in reads:
                    os.set_blocking(fd, False)
                    poller.register(fd, selectors.EVENT_READ)
                while poller.get_map() and time.monotonic() < deadline:
                    for key, _ in poller.select(.05):
                        try:
                            data = os.read(key.fd, 8192)
                        except OSError as error:
                            if terminal and key.fd == master and error.errno == errno.EIO:
                                data = b""
                            else:
                                raise
                        if data:
                            chunks[reads[key.fd]].extend(data)
                        else:
                            poller.unregister(key.fd)
                self.assertFalse(poller.get_map(), "child output/startup stalled")
            _, status = os.waitpid(pid, 0)
            reaped = True
            return {name: bytes(data) for name, data in chunks.items()}, os.waitstatus_to_exitcode(status)
        finally:
            for fd in owned:
                os.close(fd)
            if pid > 0 and not reaped:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)

    def test_arguments_environment_path_cwd_and_stdin_eof(self):
        literal = "a b;$(echo unsafe)\"'中"
        output, status = self.run_child(["sh", "-c", 'printf "%s|%s|%s" "$1" "$TC_SPAWN" "$PWD"; cat >/dev/null; printf err >&2', "sh", literal],
                                       cwd="/", env=["PATH=/bin:/usr/bin", "TC_SPAWN=old", "TC_SPAWN=exact"])
        self.assertEqual(status, 0)
        self.assertEqual(output, {"stdout": (literal + "|exact|/").encode(), "stderr": b"err", "startup": b""})

    def test_startup_failures_report_stage_and_exit(self):
        for args, cwd, stage in [(["/termcanvas-no-such-executable"], "", 5), (["/bin/sh"], "/termcanvas-no-such-cwd", 3)]:
            with self.subTest(stage=stage):
                output, status = self.run_child(args, cwd=cwd)
                self.assertEqual(status, 127)
                self.assertEqual(output["startup"], bytes([stage]))

    def test_pty_is_a_controlling_terminal_with_separate_stderr(self):
        output, status = self.run_child(["/bin/sh", "-c", "test -t 0 && test -t 1 && test ! -t 2 && test -r /dev/tty && printf pty; printf err >&2"], terminal=True)
        self.assertEqual(status, 0)
        self.assertEqual(output, {"stdout": b"pty", "stderr": b"err", "startup": b""})

    def test_execvp_script_fallback_uses_prepared_argv(self):
        script = Path(self.directory.name) / "without-shebang"
        script.write_text('printf "%s" "$1"')
        script.chmod(0o700)
        output, status = self.run_child([script.name, "literal argument"], env=["PATH=" + self.directory.name])
        self.assertEqual(status, 0)
        self.assertEqual(output["stdout"], b"literal argument")


if __name__ == "__main__":
    unittest.main()
