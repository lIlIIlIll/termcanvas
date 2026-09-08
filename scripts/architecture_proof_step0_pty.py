#!/usr/bin/env python3
"""Normalize real omp-cj PTY traces into Step-0 raw JSONL records."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shlex
import statistics
import sys
import time
from typing import Any, Iterable


DEFAULT_WORKLOADS = (
    "cold_start",
    "typing_ascii",
    "typing_cjk",
    "backspace",
    "cursor_left_right",
    "key_repeat_up_down",
    "scroll_line",
    "scroll_page",
    "scroll_continuous",
    "resize_small_width_oscillation",
    "resize_large_width_jump",
    "resize_continuous_width",
    "resize_height_only",
    "resize_width_height",
    "overlay_open",
    "overlay_close",
    "overlay_switch",
)


def load_harness(path: Path):
    spec = importlib.util.spec_from_file_location("omp_tui_pty_bench", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load PTY harness: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * fraction + 0.999999)))
    return ordered[index]


def distribution(values: Iterable[float]) -> dict[str, float | int | None]:
    samples = list(values)
    if not samples:
        return {"n": 0, "p50": None, "p95": None, "p99": None, "max": None}
    return {
        "n": len(samples),
        "p50": statistics.median(samples),
        "p95": percentile(samples, 0.95),
        "p99": percentile(samples, 0.99) if len(samples) >= 100 else None,
        "max": max(samples),
    }


def binary_identifier(command: list[str]) -> str:
    binary = Path(command[0]).resolve()
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()[:16]
    return f"sha256:{digest}"


def execute_workload(run, workload: str, operations: int) -> list[dict[str, Any]]:
    if workload == "cold_start":
        return []
    if workload == "typing_ascii":
        rows: list[dict[str, Any]] = []
        for _ in range(operations):
            rows.extend(run.send(b"a", event_names={"key_down"}))
        return rows
    if workload == "typing_cjk":
        rows = []
        text = "中文输入"
        for index in range(operations):
            rows.extend(run.send(text[index % len(text)].encode(), event_names={"key_down"}))
        return rows
    if workload == "backspace":
        run.send_batched(b"a" * operations, operations, {"key_down"})
        rows = []
        for _ in range(operations):
            rows.extend(run.send(b"\x7f", event_names={"key_down"}))
        return rows
    if workload == "cursor_left_right":
        rows = []
        for index in range(operations):
            rows.extend(run.send(b"\x1b[D" if index % 2 == 0 else b"\x1b[C", event_names={"key_down"}))
        return rows
    if workload == "key_repeat_up_down":
        rows = []
        for index in range(operations):
            rows.extend(run.send(b"\x1b[A" if index % 2 == 0 else b"\x1b[B", event_names={"key_down"}))
        return rows
    if workload == "scroll_line":
        rows: list[dict[str, Any]] = []
        for index in range(operations):
            rows.extend(run.send(b"\x1b[<64;40;10M" if index % 2 == 0 else b"\x1b[<65;40;10M", event_names={"mouse"}))
        return rows
    if workload == "scroll_page":
        rows = []
        for index in range(operations):
            rows.extend(run.send(b"\x1b[5~" if index % 2 == 0 else b"\x1b[6~", event_names={"key_down"}))
        return rows
    if workload == "scroll_continuous":
        rows = []
        for _ in range(operations):
            rows.extend(run.send(b"\x1b[A", event_names={"key_down"}))
        return rows
    if workload == "overlay_open":
        rows = []
        for _ in range(operations):
            rows.extend(run.send(b"\x1ba", event_names={"key_down"}))
            run.send(b"\x1b", event_names={"key_down"})
        return rows
    if workload == "overlay_close":
        rows = []
        for _ in range(operations):
            run.send(b"\x1ba", event_names={"key_down"})
            rows.extend(run.send(b"\x1b", event_names={"key_down"}))
        return rows
    if workload == "overlay_switch":
        return harness_run_scenario(run, "switch")

    sizes: list[tuple[int, int]] = []
    if workload == "resize_small_width_oscillation":
        # Start with a real geometry change; setting the current PTY size does
        # not emit Resize and would otherwise turn the harness wait into noise.
        sizes = [(99, 28), (100, 28)]
    elif workload == "resize_large_width_jump" or workload == "resize_width_height":
        sizes = [(60, 18), (120, 36)]
    elif workload == "resize_continuous_width":
        sizes = [(60 + index % 61, 28) for index in range(operations)]
    elif workload == "resize_height_only":
        sizes = [(100, 18), (100, 36)]
    else:
        raise ValueError(f"unknown workload: {workload}")
    rows = []
    for index in range(operations):
        width, height = sizes[index % len(sizes)]
        rows.extend(run.resize(width, height))
    return rows


def normalized_sample(
    harness, record: dict[str, Any], workload: str, sample_id: int,
    build_id: str, history: int, width: int, height: int,
) -> dict[str, Any]:
    enriched = harness.enrich(record)
    return {
        "benchmark": workload,
        "sample_id": sample_id,
        "sample_order": sample_id,
        "build_identifier": build_id,
        "history_count": history,
        "terminal_width": width,
        "terminal_height": height,
        "metrics_mode": "on",
        "stage_timings": {
            "dispatch_ms": enriched["dispatch_ms"],
            "update_ms": enriched["state_ms"],
            "layout_ms": enriched["layout_ms"],
            "render_ms": enriched["render_ms"],
            "diff_ms": -1,
            "write_ms": enriched["write_flush_ms"],
            "total_ms": enriched["total_ms"],
        },
        "counters": {
            "events_processed": 1,
            "region_visits": -1,
            "layout_calls": -1,
            "cache_hits": -1,
            "cache_misses": -1,
            "cache_evictions": -1,
            "document_requests": -1,
            "documents_materialized": -1,
            "wrap_input_bytes": -1,
            "metadata_touches": -1,
            "buffer_cell_attempts": -1,
            "buffer_cell_writes": -1,
            "diff_cells": -1,
            "diff_spans": -1,
            "ansi_bytes": int(record.get("output_bytes", 0)),
            "write_calls": int(record.get("write_calls", 0)),
            "event_queue_length": int(record.get("event_queue_length", 0)),
        },
    }


def harness_run_scenario(run, scenario: str) -> list[dict[str, Any]]:
    # The loaded module is attached by main before workloads execute. Keeping
    # this adapter tiny preserves the repository's existing scenario semantics.
    return run._step0_harness.run_scenario(run, scenario)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workloads", default=",".join(DEFAULT_WORKLOADS))
    parser.add_argument("--histories", default="100,1000,10000,100000")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--cold-runs", type=int, default=20)
    parser.add_argument("--operations", type=int, default=120)
    parser.add_argument("--width", type=int, default=100)
    parser.add_argument("--height", type=int, default=28)
    parser.add_argument("--timeout", type=float, default=12.0)
    args = parser.parse_args()
    harness = load_harness(args.harness.resolve())
    command = shlex.split(args.candidate)
    build_id = binary_identifier(command)
    workloads = tuple(item for item in args.workloads.split(",") if item)
    histories = tuple(int(item) for item in args.histories.split(",") if item)
    args.output.mkdir(parents=True, exist_ok=True)
    raw_path = args.output / "pty_samples.jsonl"
    run_path = args.output / "pty_runs.jsonl"
    sample_rows: list[dict[str, Any]] = []
    run_rows: list[dict[str, Any]] = []
    global_sample_id = 0
    with raw_path.open("w", encoding="utf-8") as raw, run_path.open("w", encoding="utf-8") as raw_runs:
        for workload in workloads:
            workload_histories = histories
            if workload == "cold_start":
                workload_histories = tuple(value for value in histories if value in (100, 10000))
            repetitions = args.cold_runs if workload == "cold_start" else args.runs
            for history in workload_histories:
                for run_index in range(repetitions):
                    session = harness.PtyRun(
                        command, args.candidate_root.resolve(), args.width, args.height,
                        history, args.operations, args.timeout,
                    )
                    session._step0_harness = harness
                    try:
                        session.start()
                        records = execute_workload(session, workload, args.operations)
                    finally:
                        session.finish()
                    for index, record in enumerate(records, 1):
                        global_sample_id += 1
                        row = normalized_sample(
                            harness, record, workload, global_sample_id, build_id, history,
                            args.width, args.height,
                        )
                        row["run"] = run_index + 1
                        raw.write(json.dumps(row, sort_keys=True) + "\n")
                        sample_rows.append(row)
                    run_row = {
                        "benchmark": workload,
                        "run": run_index + 1,
                        "build_identifier": build_id,
                        "history_count": history,
                        "terminal_width": args.width,
                        "terminal_height": args.height,
                        "metrics_mode": "on",
                        "first_visible_frame_ms": session.first_frame_wall_ms,
                        "startup_phases_ms": harness.startup_phase_durations(session),
                        "pty_bytes": session.pty_bytes,
                        "rss_kb": session.max_rss_kb,
                        "silence_fallback": session.used_silence_fallback,
                    }
                    raw_runs.write(json.dumps(run_row, sort_keys=True) + "\n")
                    run_rows.append(run_row)
                    raw.flush()
                    raw_runs.flush()
                    print(f"pty {workload} history={history} run={run_index + 1}", flush=True)

    summary: dict[str, Any] = {"sample_groups": {}, "cold_start_groups": {}}
    for workload, history in sorted({(row["benchmark"], row["history_count"]) for row in sample_rows}):
        selected = [row for row in sample_rows if row["benchmark"] == workload and row["history_count"] == history]
        summary["sample_groups"][f"{workload}/{history}"] = {
            field: distribution(row["stage_timings"][field] for row in selected)
            for field in ("dispatch_ms", "update_ms", "layout_ms", "render_ms", "write_ms", "total_ms")
        }
    for workload, history in sorted({(row["benchmark"], row["history_count"]) for row in run_rows}):
        selected = [row for row in run_rows if row["benchmark"] == workload and row["history_count"] == history]
        summary["cold_start_groups"][f"{workload}/{history}"] = {
            "first_visible_frame_ms": distribution(row["first_visible_frame_ms"] for row in selected),
            "rss_kb": distribution(row["rss_kb"] for row in selected),
        }
    (args.output / "pty_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (args.output / "pty_provenance.json").write_text(
        json.dumps({
            "schema_version": 1,
            "harness": str(args.harness.resolve()),
            "candidate": command,
            "candidate_root": str(args.candidate_root.resolve()),
            "build_identifier": build_id,
            "generated_unix_ns": time.time_ns(),
            "measurement_boundary": "PTY input receipt through application terminal flush; not photon latency",
        }, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"raw={raw_path}")
    print(f"runs={run_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
