#!/usr/bin/env python3
"""Run the provenance-locked real consumer and export frame-level Step 0.5 data."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import statistics
import sys
import time
from typing import Any, Iterable


ALL_WORKLOADS = (
    "cold_start",
    "typing_ascii", "typing_cjk", "backspace", "cursor_left_right", "key_repeat_up_down",
    "scroll_line", "scroll_page", "scroll_continuous",
    "stream_a_existing_no_wrap", "stream_b_existing_wrap", "stream_c_complete_line",
    "stream_d_append_item", "stream_tail_offscreen", "resize_small_width", "resize_large_width",
    "resize_continuous_width", "resize_height_only", "resize_width_height",
    "overlay_open", "overlay_close", "overlay_switch",
    "external_idle_completion",
)


def load_harness(path: Path):
    spec = importlib.util.spec_from_file_location("omp_tui_pty_bench_step05", path)
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
        "n": len(samples), "p50": statistics.median(samples),
        "p95": percentile(samples, 0.95),
        "p99": percentile(samples, 0.99) if len(samples) >= 100 else None,
        "max": max(samples),
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return digest


def resolve_candidate_binary(command: list[str], candidate_root: Path) -> Path:
    if not command:
        raise SystemExit("candidate command is empty")
    candidate = Path(command[0]).expanduser()
    if not candidate.is_absolute():
        candidate = candidate_root / candidate
    try:
        candidate = candidate.resolve(strict=True)
    except OSError as error:
        raise SystemExit(f"candidate binary is not available: {candidate}: {error}") from error
    if not candidate.is_file():
        raise SystemExit(f"candidate binary is not a file: {candidate}")
    return candidate


def histories_for(workload: str, requested: tuple[int, ...]) -> tuple[int, ...]:
    if workload == "cold_start":
        return tuple(value for value in requested if value in (100, 10000))
    if workload in {"scroll_line", "stream_a_existing_no_wrap", "stream_b_existing_wrap",
                    "stream_c_complete_line", "stream_d_append_item", "resize_small_width"}:
        return requested
    if workload == "stream_tail_offscreen":
        return tuple(value for value in requested if value in (100, 100000))
    if workload in {"scroll_page", "scroll_continuous"}:
        return tuple(value for value in requested if value in (100, 100000))
    return tuple(value for value in requested if value == 100000)


def execute(run, workload: str, operations: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if workload == "cold_start":
        return rows
    if workload == "typing_ascii":
        for _ in range(operations): rows.extend(run.send(b"a", event_names={"key_down"}))
    elif workload == "typing_cjk":
        text = "中文输入"
        for index in range(operations): rows.extend(run.send(text[index % len(text)].encode(), event_names={"key_down"}))
    elif workload == "backspace":
        run.send_batched(b"a" * operations, operations, {"key_down"})
        for _ in range(operations): rows.extend(run.send(b"\x7f", event_names={"key_down"}))
    elif workload == "cursor_left_right":
        run.send_batched(b"a" * operations, operations, {"key_down"})
        for index in range(operations):
            rows.extend(run.send(b"\x1b[D" if index % 2 == 0 else b"\x1b[C", event_names={"key_down"}))
    elif workload == "key_repeat_up_down":
        for index in range(operations):
            rows.extend(run.send(b"\x1b[A" if index % 2 == 0 else b"\x1b[B", event_names={"key_down"}))
    elif workload == "scroll_line":
        for index in range(operations):
            rows.extend(run.send(b"\x1b[<64;40;10M" if index % 2 == 0 else b"\x1b[<65;40;10M", event_names={"mouse"}))
    elif workload == "scroll_page":
        for index in range(operations):
            rows.extend(run.send(b"\x1b[5~" if index % 2 == 0 else b"\x1b[6~", event_names={"key_down"}))
    elif workload == "scroll_continuous":
        for _ in range(operations): rows.extend(run.send(b"\x1b[A", event_names={"key_down"}))
    elif workload == "stream_tail_offscreen":
        for _ in range(12): run.send(b"\x1b[<64;40;10M", event_names={"mouse"})
        for _ in range(operations): rows.extend(run.send(b"\x1b[15~", event_names={"key_down"}))
    elif workload.startswith("stream_"):
        key = {
            "stream_a_existing_no_wrap": b"\x1b[15~",
            "stream_b_existing_wrap": b"\x1b[17~",
            "stream_c_complete_line": b"\x1b[18~",
            "stream_d_append_item": b"\x1b[20~",
        }[workload]
        for _ in range(operations): rows.extend(run.send(key, event_names={"key_down"}))
    elif workload == "overlay_open":
        for _ in range(operations):
            rows.extend(run.send(b"\x1bOS", event_names={"key_down"}))
            run.send(b"\x1b", event_names={"key_down"})
    elif workload == "overlay_close":
        for _ in range(operations):
            run.send(b"\x1bOS", event_names={"key_down"})
            rows.extend(run.send(b"\x1b", event_names={"key_down"}))
    elif workload == "overlay_switch":
        run.send(b"\x1bOS", event_names={"key_down"})
        for _ in range(operations): rows.extend(run.send(b"j", event_names={"key_down"}))
        run.send(b"\x1b", event_names={"key_down"})
    elif workload == "external_idle_completion":
        for _ in range(operations):
            rows.extend(run.send(b"\x1b[21~", event_names={"message"}))
    else:
        if workload == "resize_small_width": sizes = [(99, 28), (100, 28)]
        elif workload == "resize_large_width": sizes = [(60, 28), (120, 28)]
        elif workload == "resize_continuous_width": sizes = [(60 + index % 61, 28) for index in range(operations)]
        elif workload == "resize_height_only": sizes = [(100, 18), (100, 36)]
        elif workload == "resize_width_height": sizes = [(60, 18), (120, 36)]
        else: raise ValueError(f"unknown workload: {workload}")
        for index in range(operations): rows.extend(run.resize(*sizes[index % len(sizes)]))
    return rows


def settle_fixture(run, timeout: float = 2.0, quiet_for: float = 0.2) -> None:
    """Exclude fixture startup completions from the measured interaction window."""
    deadline = time.monotonic() + timeout
    quiet_deadline = time.monotonic() + quiet_for
    observed = len(run.operations)
    while time.monotonic() < deadline:
        run.pump(timeout=min(0.05, max(0.0, quiet_deadline - time.monotonic())))
        if len(run.operations) != observed:
            observed = len(run.operations)
            quiet_deadline = time.monotonic() + quiet_for
        if time.monotonic() >= quiet_deadline:
            return


def milliseconds(record: dict[str, Any], field: str) -> float:
    return max(0.0, float(record.get(field, 0)) / 1_000_000.0)


def normalize(harness, record: dict[str, Any], workload: str, sample_id: int,
              binary_hash: str, history: int, mode: str, width: int, height: int) -> dict[str, Any]:
    enriched = harness.enrich(record)
    return {
        "benchmark": workload, "sample_id": sample_id, "sample_order": sample_id,
        "build_identifier": f"sha256:{binary_hash}", "history_count": history,
        "fixture_item_count": history + 1, "terminal_width": width, "terminal_height": height,
        "metrics_mode": mode,
        "stage_timings": {
            "dispatch_ms": enriched["dispatch_ms"], "update_ms": enriched["state_ms"],
            "legacy_layout_ms": enriched["layout_ms"], "legacy_render_ms": enriched["render_ms"],
            "screen_preparation_ms": milliseconds(record, "screen_preparation_ns"),
            "transcript_render_ms": milliseconds(record, "transcript_render_ns"),
            "activity_render_ms": milliseconds(record, "activity_render_ns"),
            "queue_todo_render_ms": milliseconds(record, "queue_todo_render_ns"),
            "composer_render_ms": milliseconds(record, "composer_render_ns"),
            "composer_header_ms": milliseconds(record, "composer_header_ns")
                if int(record.get("composer_header_ns", -1)) >= 0 else -1.0,
            "composer_widget_ms": milliseconds(record, "composer_widget_ns")
                if int(record.get("composer_widget_ns", -1)) >= 0 else -1.0,
            "composer_placeholder_ms": milliseconds(record, "composer_placeholder_ns")
                if int(record.get("composer_placeholder_ns", -1)) >= 0 else -1.0,
            "composer_chrome_ms": milliseconds(record, "composer_chrome_ns")
                if int(record.get("composer_chrome_ns", -1)) >= 0 else -1.0,
            "overlay_render_ms": milliseconds(record, "overlay_render_ns"),
            "product_other_ms": milliseconds(record, "product_other_ns"),
            "core_render_ms": milliseconds(record, "core_render_ns"),
            "diff_ms": milliseconds(record, "core_diff_ns"),
            "write_ms": milliseconds(record, "core_write_ns"),
            "draw_ms": milliseconds(record, "core_total_draw_ns"),
            "external_queue_ms": milliseconds(record, "external_queue_latency_ns")
                if int(record.get("external_queue_latency_ns", -1)) >= 0 else -1.0,
            "total_ms": enriched["total_ms"],
        },
        "counters": {
            "buffer_cell_attempts": int(record.get("buffer_cell_attempts", -1)),
            "buffer_cell_writes": int(record.get("buffer_cell_writes", -1)),
            "diff_cells": int(record.get("diff_cells", -1)), "diff_spans": int(record.get("diff_spans", -1)),
            "ansi_bytes": int(record.get("ansi_bytes", -1)),
            "transcript_paint_calls": int(record.get("transcript_paint_calls", -1)),
            "activity_paint_calls": int(record.get("activity_paint_calls", -1)),
            "queue_todo_paint_calls": int(record.get("queue_todo_paint_calls", -1)),
            "composer_paint_calls": int(record.get("composer_paint_calls", -1)),
            "composer_background_attempts": int(record.get("composer_background_attempts", -1)),
            "composer_header_attempts": int(record.get("composer_header_attempts", -1)),
            "composer_content_attempts": int(record.get("composer_content_attempts", -1)),
            "composer_chrome_attempts": int(record.get("composer_chrome_attempts", -1)),
            "composer_rows_visited": int(record.get("composer_rows_visited", -1)),
            "composer_rows_painted": int(record.get("composer_rows_painted", -1)),
            "composer_height_before": int(record.get("composer_height_before", -1)),
            "composer_height_after": int(record.get("composer_height_after", -1)),
            "overlay_paint_calls": int(record.get("overlay_paint_calls", -1)),
            "metadata_touches": int(record.get("vt_metadata_touches", -1)),
            "sync_count_calls": int(record.get("vt_sync_count_calls", -1)),
            "height_index_reset_entries": int(record.get("vt_height_index_reset_entries", -1)),
            "height_index_update_calls": int(record.get("vt_height_index_update_calls", -1)),
            "cache_lookups": int(record.get("vt_cache_lookups", -1)),
            "cache_hits": int(record.get("vt_cache_hits", -1)), "cache_misses": int(record.get("vt_cache_misses", -1)),
            "layout_calls": int(record.get("vt_layout_calls", -1)),
            "document_requests": int(record.get("vt_document_requests", -1)),
            "documents_materialized": int(record.get("vt_documents_materialized", -1)),
            "wrap_input_bytes": int(record.get("vt_wrap_input_bytes", -1)),
            "measurement_invalidations": int(record.get("vt_measurement_invalidations", -1)),
            "visible_items": int(record.get("vt_visible_items", -1)),
            "items_visited": int(record.get("vt_items_visited", -1)),
            "items_painted": int(record.get("vt_items_painted", -1)),
            "rows_visited": int(record.get("vt_rows_visited", -1)),
            "rows_painted": int(record.get("vt_rows_painted", -1)),
            "changed_items": int(record.get("vt_changed_items", -1)),
            "item_paint_cell_attempts": int(record.get("vt_item_paint_cell_attempts", -1)),
            "row_paint_cell_attempts": int(record.get("vt_row_paint_cell_attempts", -1)),
            "item_background_cell_attempts": int(record.get("vt_item_background_cell_attempts", -1)),
            "content_cell_attempts": int(record.get("vt_content_cell_attempts", -1)),
            "layout_rows_requested": int(record.get("vt_layout_rows_requested", -1)),
            "cached_rows_used": int(record.get("vt_cached_rows_used", -1)),
            "selective_item_invalidations": int(record.get("vt_selective_item_invalidations", -1)),
            "selective_offscreen_invalidations": int(record.get("vt_selective_offscreen_invalidations", -1)),
            "fallback_full_viewport_paints": int(record.get("vt_fallback_full_viewport_paints", -1)),
            "output_bytes": int(record.get("output_bytes", -1)), "write_calls": int(record.get("write_calls", -1)),
            "event_queue_length": int(record.get("event_queue_length", -1)),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("off", "on", "off_repeat"), required=True)
    parser.add_argument("--workloads", default=",".join(ALL_WORKLOADS))
    parser.add_argument("--histories", default="100,1000,10000,100000")
    parser.add_argument("--operations", type=int, default=120)
    parser.add_argument("--width", type=int, default=100)
    parser.add_argument("--height", type=int, default=28)
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()
    command = shlex.split(args.candidate)
    candidate_root = args.candidate_root.resolve()
    candidate_binary = resolve_candidate_binary(command, candidate_root)
    declared_binary = args.binary.expanduser()
    if not declared_binary.is_absolute():
        declared_binary = candidate_root / declared_binary
    try:
        declared_binary = declared_binary.resolve(strict=True)
    except OSError as error:
        raise SystemExit(f"declared binary is not available: {declared_binary}: {error}") from error
    if candidate_binary != declared_binary:
        raise SystemExit(
            f"candidate identity mismatch: command executes {candidate_binary}, "
            f"but --binary identifies {declared_binary}"
        )
    command[0] = str(candidate_binary)
    binary_hash = sha256(candidate_binary)
    harness = load_harness(args.harness.resolve())
    workloads = tuple(item for item in args.workloads.split(",") if item)
    histories = tuple(int(item) for item in args.histories.split(",") if item)
    args.output.mkdir(parents=True, exist_ok=True)
    raw_path = args.output / f"samples-{args.mode}.jsonl"
    runs_path = args.output / f"runs-{args.mode}.jsonl"
    samples: list[dict[str, Any]] = []
    runs: list[dict[str, Any]] = []
    sample_id = 0
    previous_env = os.environ.get("OMP_CJ_TUI_CORE_METRICS")
    os.environ["OMP_CJ_TUI_CORE_METRICS"] = "1" if args.mode == "on" else "0"
    try:
        with raw_path.open("w", encoding="utf-8") as raw, runs_path.open("w", encoding="utf-8") as raw_runs:
            for workload in workloads:
                for history in histories_for(workload, histories):
                    session = harness.PtyRun(command, candidate_root, args.width, args.height,
                                             history, args.operations, args.timeout)
                    try:
                        session.start()
                        settle_fixture(session)
                        records = execute(session, workload, args.operations)
                    finally:
                        session.finish()
                    for record in records:
                        sample_id += 1
                        row = normalize(harness, record, workload, sample_id, binary_hash, history,
                                        args.mode, args.width, args.height)
                        raw.write(json.dumps(row, sort_keys=True) + "\n")
                        samples.append(row)
                    run_row = {
                        "benchmark": workload, "history_count": history, "metrics_mode": args.mode,
                        "build_identifier": f"sha256:{binary_hash}", "first_visible_frame_ms": session.first_frame_wall_ms,
                        "pty_bytes": session.pty_bytes, "rss_kb": session.max_rss_kb,
                        "process_returncode": session.process.returncode if session.process is not None else None,
                        "runtime_sdk_root": os.environ.get("OMP_CJ_SDK_ROOT", ""),
                        "sample_count": len(records), "generated_unix_ns": time.time_ns(),
                    }
                    raw_runs.write(json.dumps(run_row, sort_keys=True) + "\n")
                    runs.append(run_row)
                    raw.flush(); raw_runs.flush()
                    print(f"{args.mode} {workload}/{history} n={len(records)}", flush=True)
    finally:
        if previous_env is None: os.environ.pop("OMP_CJ_TUI_CORE_METRICS", None)
        else: os.environ["OMP_CJ_TUI_CORE_METRICS"] = previous_env

    summary: dict[str, Any] = {"mode": args.mode, "groups": {}}
    for workload, history in sorted({(row["benchmark"], row["history_count"]) for row in samples}):
        selected = [row for row in samples if row["benchmark"] == workload and row["history_count"] == history]
        summary["groups"][f"{workload}/{history}"] = {
            "timings": {field: distribution(row["stage_timings"][field] for row in selected)
                        for field in selected[0]["stage_timings"]},
            "counters": {field: distribution(float(row["counters"][field]) for row in selected)
                         for field in selected[0]["counters"]},
        }
    (args.output / f"summary-{args.mode}.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"raw={raw_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
