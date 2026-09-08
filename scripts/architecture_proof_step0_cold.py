#!/usr/bin/env python3
"""Measure process-spawn to first PTY output for an uninstrumented minimal TUI."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import selectors
import shlex
import signal
import statistics
import struct
import subprocess
import sys
import termios
import time


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * fraction + 0.999999)))
    return ordered[index]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=20)
    parser.add_argument("--width", type=int, default=100)
    parser.add_argument("--height", type=int, default=28)
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()
    command = shlex.split(args.candidate)
    binary = Path(command[0]).resolve()
    build_id = "sha256:" + hashlib.sha256(binary.read_bytes()).hexdigest()[:16]
    args.output.mkdir(parents=True, exist_ok=True)
    samples: list[float] = []
    raw_path = args.output / "cold_minimal.jsonl"
    with raw_path.open("w", encoding="utf-8") as raw:
        for run in range(1, args.runs + 1):
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", args.height, args.width, 0, 0))
            env = os.environ.copy()
            env.update({"TERM": "xterm-256color", "NO_COLOR": "1"})
            started = time.monotonic_ns()
            process = subprocess.Popen(
                command, cwd=args.candidate_root, env=env, stdin=slave,
                stdout=slave, stderr=subprocess.DEVNULL, start_new_session=True,
                close_fds=True,
            )
            os.close(slave)
            selector = selectors.DefaultSelector()
            selector.register(master, selectors.EVENT_READ)
            deadline = time.monotonic() + args.timeout
            first_bytes = 0
            try:
                while time.monotonic() < deadline and first_bytes == 0:
                    for key, _ in selector.select(0.05):
                        chunk = os.read(key.fd, 65536)
                        if chunk:
                            first_bytes = len(chunk)
                            break
                if first_bytes == 0:
                    raise TimeoutError("no visible PTY bytes before timeout")
                elapsed_ms = (time.monotonic_ns() - started) / 1_000_000
                samples.append(elapsed_ms)
                record = {
                    "benchmark": "cold_start_minimal",
                    "sample_id": run,
                    "sample_order": run,
                    "build_identifier": build_id,
                    "history_count": 0,
                    "terminal_width": args.width,
                    "terminal_height": args.height,
                    "metrics_mode": "off",
                    "stage_timings": {"process_to_first_visible_frame_ms": elapsed_ms},
                    "counters": {"first_read_bytes": first_bytes},
                }
                raw.write(json.dumps(record, sort_keys=True) + "\n")
                raw.flush()
                print(f"cold minimal run={run} first={elapsed_ms:.3f}ms", flush=True)
            finally:
                selector.close()
                try:
                    if process.poll() is None:
                        os.write(master, b"\x03")
                        process.wait(timeout=1)
                except (OSError, subprocess.TimeoutExpired):
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGTERM)
                        process.wait(timeout=2)
                os.close(master)
    summary = {
        "n": len(samples),
        "p50": statistics.median(samples),
        "p95": percentile(samples, 0.95),
        "p99": percentile(samples, 0.99) if len(samples) >= 100 else None,
        "max": max(samples),
        "measurement_boundary": "process spawn immediately before Popen through first non-empty PTY read",
        "build_identifier": build_id,
    }
    (args.output / "cold_minimal_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
