#!/usr/bin/env python3
"""Measure real-consumer same-height and geometry-changing streaming bursts."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import statistics
import time
from typing import Any


def load_harness(path: Path):
    spec = importlib.util.spec_from_file_location("omp_tui_pty_bench_step3b5", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load PTY harness: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * fraction + 0.999999)))
    return ordered[index]


def distribution(values: list[float]) -> dict[str, float | int | None]:
    if not values:
        return {"n": 0, "p50": None, "p95": None, "p99": None, "max": None}
    return {
        "n": len(values),
        "p50": statistics.median(values),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99) if len(values) >= 100 else None,
        "max": max(values),
    }


def frame_value(frame: dict[str, Any], field: str, scale: float = 1.0) -> float:
    return float(frame.get(field, 0)) / scale


def run_same_height(
    harness, args, cadence_ms: int, run_id: int, inject_input: bool, inject_resize: bool = False
):
    os.environ["OMP_CJ_TUI_CORE_METRICS"] = "1" if args.mode == "on" else "0"
    os.environ["CJ_TUI_FRAME_COALESCE_MS"] = str(args.frame_budget_ms)
    os.environ["OMP_CJ_TUI_SAME_HEIGHT_BURST_INTERVAL_MS"] = str(cadence_ms)
    session = harness.PtyRun(
        [str(args.binary), "--fixture"], args.consumer_root, args.width, args.height,
        args.history, args.tokens, args.timeout,
    )
    input_written_ns: int | None = None
    input_visible_ns: int | None = None
    resize_injected = False
    resize_frames: list[dict[str, Any]] = []
    try:
        session.start()
        session.wait_for_silence(0.05, timeout=args.timeout)
        before_start = len(session.operations)
        os.write(session.master_fd, b"\x1b[24~")
        start_deadline = time.monotonic() + args.timeout
        while time.monotonic() < start_deadline:
            session.pump(0.02)
            if any(bool(frame.get("burst_proof_active", False))
                   for frame in session.operations[before_start:]):
                break
        else:
            raise TimeoutError("same-height fixture did not become active")
        start_index = len(session.operations)
        cpu_start = session._cpu_ticks()
        burst_started_ns = time.monotonic_ns()
        last_total = 0
        quiet_since = time.monotonic()
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            before = len(session.operations)
            session.pump(0.02)
            if len(session.operations) != before:
                quiet_since = time.monotonic()
            new_frames = session.operations[start_index:]
            totals = [int(frame.get("burst_tokens_applied_total", 0)) for frame in new_frames]
            if totals:
                last_total = max(totals)
            if inject_input and input_written_ns is None and last_total >= 20 and last_total < args.tokens:
                input_written_ns = time.monotonic_ns()
                os.write(session.master_fd, b"z")
            if inject_resize and not resize_injected and last_total >= 20 and last_total < args.tokens:
                resize_frames.extend(session.resize(args.width - 80, args.height))
                resize_injected = True
            if input_written_ns is not None and input_visible_ns is None:
                if any(frame.get("event") == "key_down" for frame in new_frames):
                    input_visible_ns = time.monotonic_ns()
            if last_total >= args.tokens and time.monotonic() - quiet_since >= 0.10:
                break
            if session.process is not None and session.process.poll() is not None:
                raise RuntimeError(f"TUI exited early with status {session.process.returncode}")
        if last_total != args.tokens:
            raise RuntimeError(f"same-height burst applied {last_total}/{args.tokens} tokens")
        cpu_end = session._cpu_ticks()
        burst_finished_ns = time.monotonic_ns()
        frames = [
            frame for frame in session.operations[start_index:]
            if int(frame.get("burst_tokens_applied", 0)) > 0
        ]
        invalid = [] if inject_resize else [
            frame for frame in frames
            if int(frame.get("burst_item_height_before", -1)) != int(frame.get("burst_item_height_after", -2))
            or not bool(frame.get("burst_bounds_stable", False))
            or not bool(frame.get("burst_visible_mapping_stable", False))
            or not bool(frame.get("burst_follow_bottom", False))
            or not bool(frame.get("burst_precise_dirty_hit", False))
            or int(frame.get("vt_fallback_full_viewport_paints", 0)) > 0
            or (not inject_input and int(frame.get("composer_paint_calls", 0)) != 0)
            or (int(frame.get("vt_items_painted", 1)) >= 0 and int(frame.get("vt_items_painted", 1)) != 1)
            or (int(frame.get("vt_rows_painted", 1)) >= 0 and int(frame.get("vt_rows_painted", 1)) != 1)
        ]
        input_frames = [frame for frame in session.operations[start_index:] if frame.get("event") == "key_down"]
        input_frame = input_frames[0] if input_frames else None
        hz = os.sysconf("SC_CLK_TCK")
        last = frames[-1]
        run = {
            "scenario": (
                "resize_under_burst" if inject_resize else
                ("same_height_input" if inject_input else "same_height")
            ),
            "mode": args.mode,
            "frame_budget_ms": args.frame_budget_ms,
            "cadence_ms": cadence_ms,
            "run_id": run_id,
            "tokens_produced": args.tokens,
            "tokens_applied": last_total,
            "frames_produced": len(frames),
            "frames_per_token": len(frames) / args.tokens,
            "tokens_per_frame": args.tokens / len(frames),
            "runtime_updates": sum(int(frame.get("updates_per_frame", 0)) for frame in frames),
            "frame_requests": int(last.get("frame_requests", 0)),
            "frame_requests_merged": int(last.get("frame_requests_merged", 0)),
            "frames_avoided": int(last.get("frames_avoided", 0)),
            "ready_markers_processed": int(last.get("burst_ready_markers_processed", 0)),
            "external_accepted": int(last.get("burst_external_accepted", 0)),
            "external_full": int(last.get("burst_external_full", 0)),
            "wake_signals": int(last.get("burst_wake_signals", 0)),
            "observed_event_queue_max": max(int(frame.get("event_queue_length", 0)) for frame in frames),
            "cpu_seconds": max(0, cpu_end - cpu_start) / hz,
            "wall_ms": (burst_finished_ns - burst_started_ns) / 1_000_000.0,
            "valid_frames": len(frames) - len(invalid),
            "invalid_frames": len(invalid),
            "input_injected": inject_input,
            "input_frames": len(input_frames),
            "resize_injected": resize_injected,
            "resize_frames": len(resize_frames),
            "resize_requests_observed": max(
                [int(frame.get("resize_frame_requests", 0)) for frame in resize_frames] + [0]
            ),
            "input_write_to_visible_ms": (
                (input_visible_ns - input_written_ns) / 1_000_000.0
                if input_written_ns is not None and input_visible_ns is not None else None
            ),
            "input_update_ms": (
                max(0, int(input_frame.get("state_update_completed_ns", 0)) -
                    int(input_frame.get("event_dispatch_completed_ns", 0))) / 1_000_000.0
                if input_frame is not None else None
            ),
            "input_render_ms": (
                max(0, int(input_frame.get("render_completed_ns", 0)) -
                    int(input_frame.get("render_started_ns", 0))) / 1_000_000.0
                if input_frame is not None else None
            ),
            "input_runtime_to_visible_ms": (
                max(0, int(input_frame.get("terminal_flush_completed_ns", 0)) -
                    int(input_frame.get("input_received_ns", 0))) / 1_000_000.0
                if input_frame is not None else None
            ),
            "binary_sha256": args.binary_sha256,
        }
        # Preserve the injected keyboard frame as raw attribution evidence.
        # Validity and frames/token continue to use only token-applied frames.
        return run, frames + input_frames + resize_frames
    finally:
        session.finish()


def run_geometry_control(harness, args, run_id: int):
    os.environ["OMP_CJ_TUI_CORE_METRICS"] = "1" if args.mode == "on" else "0"
    os.environ["CJ_TUI_FRAME_COALESCE_MS"] = str(args.frame_budget_ms)
    session = harness.PtyRun(
        [str(args.binary), "--fixture"], args.consumer_root, 120, 40,
        args.history, args.tokens, args.timeout,
    )
    try:
        session.start()
        session.wait_for_silence(0.05, timeout=args.timeout)
        start_index = len(session.operations)
        os.write(session.master_fd, b"\x1b[19~")
        cpu_start = session._cpu_ticks()
        started_ns = time.monotonic_ns()
        deadline = time.monotonic() + max(args.timeout, 60.0)
        frames: list[dict[str, Any]] = []
        while time.monotonic() < deadline:
            session.pump(0.02)
            frames = [frame for frame in session.operations[start_index:] if frame.get("event") == "timer"]
            if sum(int(frame.get("updates_per_frame", 0)) for frame in frames) >= args.tokens:
                break
        runtime_updates = sum(int(frame.get("updates_per_frame", 0)) for frame in frames)
        if runtime_updates < args.tokens:
            raise TimeoutError(
                f"geometry control processed {runtime_updates}/{args.tokens} updates in {len(frames)} frames"
            )
        cpu_end = session._cpu_ticks()
        finished_ns = time.monotonic_ns()
        hz = os.sysconf("SC_CLK_TCK")
        return {
            "scenario": "geometry_control",
            "mode": args.mode,
            "frame_budget_ms": args.frame_budget_ms,
            "cadence_ms": 5,
            "run_id": run_id,
            "tokens_produced": args.tokens,
            "tokens_applied": args.tokens,
            "frames_produced": len(frames),
            "frames_per_token": len(frames) / args.tokens,
            "tokens_per_frame": args.tokens / len(frames),
            "runtime_updates": runtime_updates,
            "frame_requests": int(frames[-1].get("frame_requests", 0)),
            "frame_requests_merged": int(frames[-1].get("frame_requests_merged", 0)),
            "frames_avoided": int(frames[-1].get("frames_avoided", 0)),
            "ready_markers_processed": 0,
            "external_accepted": 0,
            "external_full": 0,
            "wake_signals": 0,
            "observed_event_queue_max": max(int(frame.get("event_queue_length", 0)) for frame in frames),
            "cpu_seconds": max(0, cpu_end - cpu_start) / hz,
            "wall_ms": (finished_ns - started_ns) / 1_000_000.0,
            "valid_frames": len(frames),
            "invalid_frames": 0,
            "input_injected": False,
            "input_frames": 0,
            "input_write_to_visible_ms": None,
            "input_update_ms": None,
            "input_render_ms": None,
            "input_runtime_to_visible_ms": None,
            "binary_sha256": args.binary_sha256,
        }, frames
    finally:
        session.finish()


def summarize(runs: list[dict[str, Any]], frames: list[dict[str, Any]]):
    numeric_frames = {
        "render_ms": [frame_value(frame, "core_render_ns", 1_000_000.0) for frame in frames],
        "total_frame_ms": [
            max(0.0, frame_value(frame, "terminal_flush_completed_ns") - frame_value(frame, "input_received_ns"))
            / 1_000_000.0 for frame in frames
        ],
        "queue_wait_ms": [
            frame_value(frame, "external_queue_latency_ns", 1_000_000.0)
            for frame in frames if int(frame.get("external_queue_latency_ns", -1)) >= 0
        ],
        "enqueue_to_visible_ms": [
            (frame_value(frame, "external_queue_latency_ns") +
             max(0.0, frame_value(frame, "terminal_flush_completed_ns") - frame_value(frame, "input_received_ns")))
            / 1_000_000.0
            for frame in frames if int(frame.get("external_queue_latency_ns", -1)) >= 0
        ],
        "update_ms": [
            max(0.0, frame_value(frame, "state_update_completed_ns") - frame_value(frame, "input_received_ns"))
            / 1_000_000.0 for frame in frames
        ],
        "buffer_attempts": [float(frame.get("buffer_cell_attempts", -1)) for frame in frames
                            if int(frame.get("buffer_cell_attempts", -1)) >= 0],
        "buffer_writes": [float(frame.get("buffer_cell_writes", -1)) for frame in frames
                          if int(frame.get("buffer_cell_writes", -1)) >= 0],
        "items_painted": [float(frame.get("vt_items_painted", -1)) for frame in frames
                          if int(frame.get("vt_items_painted", -1)) >= 0],
        "rows_painted": [float(frame.get("vt_rows_painted", -1)) for frame in frames
                         if int(frame.get("vt_rows_painted", -1)) >= 0],
        "diff_cells": [float(frame.get("diff_cells", 0)) for frame in frames],
        "diff_spans": [float(frame.get("diff_spans", 0)) for frame in frames],
        "ansi_bytes": [float(frame.get("ansi_bytes", 0)) for frame in frames],
        "updates_per_frame": [float(frame.get("updates_per_frame", 0)) for frame in frames],
        "first_invalidation_to_frame_ms": [
            float(frame.get("first_invalidation_to_frame_ms", 0)) for frame in frames
        ],
        "last_update_to_frame_ms": [float(frame.get("last_update_to_frame_ms", 0)) for frame in frames],
        "coalescing_delay_ms": [
            float(frame.get("frame_delay_due_to_coalescing_ms", 0)) for frame in frames
        ],
    }
    return {
        "frame_count": len(frames),
        "frame": {name: distribution(values) for name, values in numeric_frames.items()},
        "burst": {
            "count": len(runs),
            "frames_per_token": distribution([float(run["frames_per_token"]) for run in runs]),
            "tokens_per_frame": distribution([float(run["tokens_per_frame"]) for run in runs]),
            "cpu_seconds": distribution([float(run["cpu_seconds"]) for run in runs]),
            "wall_ms": distribution([float(run["wall_ms"]) for run in runs]),
            "ready_markers_processed": distribution([float(run["ready_markers_processed"]) for run in runs]),
            "runtime_updates": distribution([float(run["runtime_updates"]) for run in runs]),
            "frames_avoided": distribution([float(run["frames_avoided"]) for run in runs]),
            "external_accepted": distribution([float(run["external_accepted"]) for run in runs]),
            "external_full": distribution([float(run["external_full"]) for run in runs]),
            "wake_signals": distribution([float(run["wake_signals"]) for run in runs]),
            "observed_event_queue_max": max(int(run["observed_event_queue_max"]) for run in runs),
            "invalid_frames": sum(int(run["invalid_frames"]) for run in runs),
            "input_write_to_visible_ms": distribution([
                float(run["input_write_to_visible_ms"]) for run in runs
                if run["input_write_to_visible_ms"] is not None
            ]),
            "input_update_ms": distribution([
                float(run["input_update_ms"]) for run in runs
                if run["input_update_ms"] is not None
            ]),
            "input_render_ms": distribution([
                float(run["input_render_ms"]) for run in runs
                if run["input_render_ms"] is not None
            ]),
            "input_runtime_to_visible_ms": distribution([
                float(run["input_runtime_to_visible_ms"]) for run in runs
                if run["input_runtime_to_visible_ms"] is not None
            ]),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--consumer-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("off", "on", "off_repeat"), required=True)
    parser.add_argument("--cadences", default="0,1,10")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--tokens", type=int, default=60)
    parser.add_argument("--history", type=int, default=100000)
    parser.add_argument("--width", type=int, default=400)
    parser.add_argument("--height", type=int, default=40)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--input-cadence", type=int, default=10)
    parser.add_argument("--geometry-control", action="store_true")
    parser.add_argument("--resize-under-burst", action="store_true")
    parser.add_argument("--frame-budget-ms", type=int, default=0)
    args = parser.parse_args()
    import hashlib
    args.binary = args.binary.resolve()
    args.consumer_root = args.consumer_root.resolve()
    args.binary_sha256 = hashlib.sha256(args.binary.read_bytes()).hexdigest()
    harness = load_harness(args.harness.resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    all_runs: list[dict[str, Any]] = []
    all_frames: list[dict[str, Any]] = []
    for cadence in [int(value) for value in args.cadences.split(",") if value != ""]:
        for run_id in range(1, args.runs + 1):
            run, frames = run_same_height(harness, args, cadence, run_id, False)
            for frame in frames:
                frame["_proof_scenario"] = "same_height"
                frame["_proof_run_id"] = run_id
            all_runs.append(run); all_frames.extend(frames)
            print(f"{args.mode} same-height cadence={cadence} run={run_id} frames={len(frames)}")
    for run_id in range(1, args.runs + 1):
        run, frames = run_same_height(harness, args, args.input_cadence, run_id, True)
        for frame in frames:
            frame["_proof_scenario"] = "same_height_input"
            frame["_proof_run_id"] = run_id
        all_runs.append(run); all_frames.extend(frames)
        print(f"{args.mode} input cadence={args.input_cadence} run={run_id} frames={len(frames)}")
    if args.resize_under_burst:
        for run_id in range(1, args.runs + 1):
            run, frames = run_same_height(
                harness, args, args.input_cadence, run_id, False, inject_resize=True
            )
            for frame in frames:
                frame["_proof_scenario"] = "resize_under_burst"
                frame["_proof_run_id"] = run_id
            all_runs.append(run); all_frames.extend(frames)
            print(f"{args.mode} resize-under-burst run={run_id} frames={len(frames)}")
    if args.geometry_control:
        for run_id in range(1, args.runs + 1):
            run, frames = run_geometry_control(harness, args, run_id)
            for frame in frames:
                frame["_proof_scenario"] = "geometry_control"
                frame["_proof_run_id"] = run_id
            all_runs.append(run); all_frames.extend(frames)
            print(f"{args.mode} geometry-control run={run_id} frames={len(frames)}")
    suffix = f"{args.mode}-budget-{args.frame_budget_ms}ms"
    with (args.output / f"runs-{suffix}.jsonl").open("w", encoding="utf-8") as handle:
        for run in all_runs: handle.write(json.dumps(run, sort_keys=True) + "\n")
    with (args.output / f"frames-{suffix}.jsonl").open("w", encoding="utf-8") as handle:
        for frame in all_frames: handle.write(json.dumps(frame, sort_keys=True) + "\n")
    grouped: dict[str, Any] = {}
    for scenario in sorted({str(run["scenario"]) for run in all_runs}):
        for cadence in sorted({int(run["cadence_ms"]) for run in all_runs if run["scenario"] == scenario}):
            runs = [run for run in all_runs if run["scenario"] == scenario and run["cadence_ms"] == cadence]
            frames = [frame for frame in all_frames if frame.get("_proof_scenario") == scenario]
            if scenario != "geometry_control":
                frames = [frame for frame in frames if int(frame.get("burst_interval_ms", -1)) == cadence]
            grouped[f"{scenario}/{cadence}"] = summarize(runs, frames)
    summary = {
        "mode": args.mode,
        "frame_budget_ms": args.frame_budget_ms,
        "binary_sha256": args.binary_sha256,
        "history": args.history,
        "terminal": {"width": args.width, "height": args.height},
        "tokens_per_burst": args.tokens,
        "groups": grouped,
    }
    (args.output / f"summary-{suffix}.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
