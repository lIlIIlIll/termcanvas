#!/usr/bin/env python3
"""Real-consumer Composer attribution matrix for Architecture Proof Step 3C."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import time


SCENARIOS: dict[str, tuple[str, bytes, tuple[bytes, ...]]] = {
    "ascii": ("", b"a", ()),
    "cjk": ("", "界".encode(), ()),
    "emoji": ("", "🙂".encode(), ()),
    "combining": ("e", "\u0301".encode(), ()),
    "backspace": ("ab", b"\x7f", ()),
    "cursor_left": ("abcd", b"\x1b[D", ()),
    "cursor_right": ("abcd", b"\x1b[C", (b"\x1b[D",)),
    "long_single_100": ("a" * 100, b"b", ()),
    "wrap_same_height": ("a" * 397, b"b", ()),
    "wrap_height_grow": ("a" * 792, b"b", ()),
    "multiline_10": ("x\n" * 9 + "tail", b"b", ()),
    "multiline_100": ("x\n" * 99 + "tail", b"b", ()),
}


def load_harness(path: Path):
    spec = importlib.util.spec_from_file_location("omp_tui_pty_bench_step3c", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load PTY harness: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def start_burst(session, timeout: float) -> None:
    os.write(session.master_fd, b"\x1b[24~")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        session.pump(0.02)
        totals = [int(row.get("burst_tokens_applied_total", 0)) for row in session.operations]
        if totals and max(totals) >= 5:
            return
    raise TimeoutError("same-height stabilization burst did not start")


def wait_for_burst_tokens(session, target: int, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        session.pump(0.02)
        totals = [int(row.get("burst_tokens_applied_total", 0)) for row in session.operations]
        if totals and max(totals) >= target:
            return
    raise TimeoutError(f"same-height burst did not reach token {target}")


def send_one(session, payload: bytes, timeout: float) -> tuple[dict, float]:
    before = len(session.operations)
    written = time.monotonic_ns()
    os.write(session.master_fd, payload)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        session.pump(0.02)
        for row in session.operations[before:]:
            if row.get("event") in {"key_down", "paste"}:
                return row, (time.monotonic_ns() - written) / 1_000_000.0
        if session.process is not None and session.process.poll() is not None:
            raise RuntimeError(f"TUI exited early with status {session.process.returncode}")
    raise TimeoutError("Composer operation did not produce a frame")


def paste(session, text: str, timeout: float) -> None:
    if not text:
        return
    _, _ = send_one(session, b"\x1b[200~" + text.encode() + b"\x1b[201~", timeout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--consumer-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("off", "on", "off_repeat"), required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--scenarios", default=",".join(SCENARIOS))
    parser.add_argument("--history", type=int, default=100000)
    parser.add_argument("--width", type=int, default=400)
    parser.add_argument("--height", type=int, default=40)
    parser.add_argument("--timeout", type=float, default=180.0)
    args = parser.parse_args()
    harness = load_harness(args.harness.resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    selected = [name for name in args.scenarios.split(",") if name]
    unknown = [name for name in selected if name not in SCENARIOS]
    if unknown:
        raise SystemExit(f"unknown scenarios: {','.join(unknown)}")
    os.environ["OMP_TERMCANVAS_CORE_METRICS"] = "1" if args.mode == "on" else "0"
    os.environ["OMP_TERMCANVAS_SAME_HEIGHT_BURST_INTERVAL_MS"] = "10"
    raw_path = args.output / f"samples-{args.mode}.jsonl"
    with raw_path.open("w", encoding="utf-8") as raw:
        for scenario in selected:
            setup, action, pre_actions = SCENARIOS[scenario]
            for run_id in range(1, args.runs + 1):
                session = harness.PtyRun(
                    [str(args.binary.resolve())], args.consumer_root.resolve(),
                    args.width, args.height, args.history, 60, args.timeout,
                )
                try:
                    session.start()
                    session.wait_for_silence(0.05, args.timeout)
                    paste(session, setup, args.timeout)
                    for payload in pre_actions:
                        _, _ = send_one(session, payload, args.timeout)
                    start_burst(session, args.timeout)
                    wait_for_burst_tokens(session, 20, args.timeout)
                    frame, visible_ms = send_one(session, action, args.timeout)
                    row = dict(frame)
                    row.update({
                        "scenario": scenario,
                        "run_id": run_id,
                        "metrics_mode": args.mode,
                        "history_count": args.history,
                        "terminal_width": args.width,
                        "terminal_height": args.height,
                        "pty_write_to_frame_observed_ms": visible_ms,
                    })
                    raw.write(json.dumps(row, sort_keys=True) + "\n")
                    print(f"{args.mode} {scenario} run={run_id}")
                finally:
                    session.finish()
    manifest = {
        "schema_version": 1,
        "binary": str(args.binary.resolve()),
        "consumer_root": str(args.consumer_root.resolve()),
        "mode": args.mode,
        "runs": args.runs,
        "scenarios": selected,
        "history": args.history,
        "terminal": {"width": args.width, "height": args.height},
        "stabilization": "real F12 producer -> ExternalPort -> RuntimeQueue, measured during 60-token 10ms burst",
        "samples": str(raw_path.resolve()),
    }
    (args.output / f"manifest-{args.mode}.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
