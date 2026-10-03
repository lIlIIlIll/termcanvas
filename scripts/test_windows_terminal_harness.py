#!/usr/bin/env python3
"""Transport contract tests, runnable without Windows; native CI runs ConPTY."""
from pathlib import Path
import json
import socket
import types
import unittest
from unittest.mock import patch

from native_terminal_harness import run_checks
from windows_terminal_harness import ConPtySession


class FakeProcess:
    fault = None
    instances = []

    @classmethod
    def spawn(cls, argv, **options):
        instance = cls(argv, options)
        cls.instances.append(instance)
        return instance

    def __init__(self, argv, options):
        self.mode = argv[1]
        self.observations = Path(argv[2])
        self.options = options
        self.live = True
        self.closed = False
        self.killed = False
        self.exitstatus = None
        self.sizes = []
        self.inputs = []
        self.pty = types.SimpleNamespace(isalive=lambda: self.live)
        self.fileobj, self.writer = socket.socketpair()
        # Deliberately contains no complete status marker, just a screen diff.
        self.writer.sendall(b"\x1b[1;8HREADY")
        self.mark("NATIVE_READY")
        if self.fault != "raw":
            self.mark("NATIVE_RAW_OK")

    def mark(self, value):
        (self.observations / value).write_text(value, encoding="ascii")

    def finish(self, code):
        if self.fault != "restore":
            self.mark("NATIVE_CONSOLE_RESTORED")
        self.exitstatus = 99 if self.fault == "exit" else code
        self.live = False
        self.writer.close()

    def write(self, text):
        self.inputs.append(text)
        if text == "q":
            self.finish(0)
        elif text == "x" and self.mode == "exception":
            self.mark("NATIVE_EXPECTED_EXCEPTION")
            self.finish(17)
        elif text == "x":
            self.mark("NATIVE_LOAD_INPUT_OK" if self.mode == "load" else "NATIVE_INPUT_OK")
        elif text == "w":
            self.mark("NATIVE_AWAKE")
        elif text == "界😀":
            self.mark("NATIVE_UNICODE_BMP_OK")
            self.mark("NATIVE_UNICODE_PAIR_OK")
        elif text == "\x1b[A":
            self.mark("NATIVE_ARROW_OK")
        elif text == "l":
            self.mark("NATIVE_LOAD_ACTIVE")
            if self.fault != "ticks":
                self.mark("NATIVE_LOAD_TICKS_OK")
        elif text == "s":
            counts = {"accepted": 2048, "received": 2047 if self.fault == "lost" else 2048,
                      "ticks": 4, "frames": 8, "inputs": 1, "resizes": 1,
                      "backpressure": 16, "queue_max": 128, "queue_overflows": 0}
            (self.observations / "NATIVE_LOAD_COUNTS.json").write_text(json.dumps(counts), encoding="utf-8")
            self.mark("NATIVE_LOAD_DRAINED")

    def setwinsize(self, rows, cols):
        self.sizes.append((rows, cols))
        self.mark(f"NATIVE_RESIZE_{cols}x{rows}")

    def kill(self, _signal):
        self.killed = True
        self.live = False
        self.exitstatus = 1

    def close(self, force=False):
        self.closed = True
        self.fileobj.close()
        self.writer.close()


class ConPtyContractTests(unittest.TestCase):
    def setUp(self):
        FakeProcess.fault = None
        FakeProcess.instances = []
        winpty = types.ModuleType("winpty")
        winpty.PtyProcess = FakeProcess
        enums = types.ModuleType("winpty.enums")
        enums.Backend = types.SimpleNamespace(ConPTY=0)
        self.modules = patch.dict("sys.modules", {"winpty": winpty, "winpty.enums": enums})
        self.modules.start()
        self.version = patch("windows_terminal_harness.version", return_value="3.0.5")
        self.version.start()
        self.addCleanup(self.modules.stop)
        self.addCleanup(self.version.stop)

    def checks(self):
        return run_checks(Path("probe.exe"), {"PYWINPTY_BACKEND": "1"}, 0.05, ConPtySession)

    def test_four_scenarios_use_conpty_and_console_observations(self):
        report = self.checks()
        self.assertEqual([item["scenario"] for item in report], ["input", "external", "load", "exception"])
        for instance in FakeProcess.instances:
            self.assertEqual(instance.options["backend"], "0")
            self.assertEqual(instance.options["dimensions"], (24, 80))
            self.assertTrue(instance.closed)
            self.assertFalse(instance.observations.exists())
            self.assertTrue(all("\n" not in value for value in instance.inputs))
        self.assertEqual(FakeProcess.instances[0].sizes, [(31, 93)])
        self.assertEqual(FakeProcess.instances[2].sizes, [(37, 101)])
        self.assertEqual(FakeProcess.instances[3].exitstatus, 17)

    def test_load_rejects_lost_accepted_events(self):
        FakeProcess.fault = "lost"
        with self.assertRaisesRegex(AssertionError, "lost accepted events"):
            self.checks()
        self.assertTrue(FakeProcess.instances[2].killed)
        self.assertTrue(FakeProcess.instances[2].closed)

    def test_load_rejects_starved_timers(self):
        FakeProcess.fault = "ticks"
        with self.assertRaisesRegex(AssertionError, "NATIVE_LOAD_TICKS_OK"):
            self.checks()
        self.assertTrue(FakeProcess.instances[2].killed)

    def test_missing_raw_evidence_fails_and_terminates_child(self):
        FakeProcess.fault = "raw"
        with self.assertRaisesRegex(AssertionError, "NATIVE_RAW_OK"):
            self.checks()
        self.assertTrue(FakeProcess.instances[0].killed)
        self.assertTrue(FakeProcess.instances[0].closed)

    def test_missing_console_restore_never_passes_on_zero_exit(self):
        FakeProcess.fault = "restore"
        with self.assertRaisesRegex(AssertionError, "NATIVE_CONSOLE_RESTORED"):
            self.checks()

    def test_unexpected_exit_never_passes_with_restore_marker(self):
        FakeProcess.fault = "exit"
        with self.assertRaisesRegex(AssertionError, "expected exit 0; got 99"):
            self.checks()

    def test_unsupported_dependency_fails_explicitly(self):
        with patch("windows_terminal_harness.version", return_value="3.0.4"):
            with self.assertRaisesRegex(ValueError, "requires pywinpty==3.0.5"):
                self.checks()


if __name__ == "__main__":
    unittest.main()
