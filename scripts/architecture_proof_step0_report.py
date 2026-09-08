#!/usr/bin/env python3
"""Merge Step-0 raw artifacts and emit one machine-readable report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import statistics
from typing import Any, Iterable


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


def jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-summary", type=Path, required=True)
    parser.add_argument("--pty-samples", type=Path, action="append", default=[])
    parser.add_argument("--pty-runs", type=Path, action="append", default=[])
    parser.add_argument("--cold-minimal-summary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Later files replace an earlier group. This lets a corrected sequential
    # input run supersede a coalesced diagnostic run without deleting raw data.
    sample_groups: dict[tuple[str, int], list[dict[str, Any]]] = {}
    for path in args.pty_samples:
        for row in jsonl(path):
            sample_groups.setdefault((row["benchmark"], row["history_count"]), [])
        by_group: dict[tuple[str, int], list[dict[str, Any]]] = {}
        for row in jsonl(path):
            by_group.setdefault((row["benchmark"], row["history_count"]), []).append(row)
        sample_groups.update(by_group)
    run_groups: dict[tuple[str, int], list[dict[str, Any]]] = {}
    for path in args.pty_runs:
        by_group = {}
        for row in jsonl(path):
            by_group.setdefault((row["benchmark"], row["history_count"]), []).append(row)
        run_groups.update(by_group)
    pty_summary = {}
    for key, rows in sorted(sample_groups.items()):
        pty_summary[f"{key[0]}/{key[1]}"] = {
            field: distribution(row["stage_timings"][field] for row in rows)
            for field in ("dispatch_ms", "update_ms", "layout_ms", "render_ms", "write_ms", "total_ms")
        }
    cold_summary = {}
    for key, rows in sorted(run_groups.items()):
        if key[0] != "cold_start":
            continue
        cold_summary[f"omp_{key[1]}"] = {
            "first_visible_frame_ms": distribution(row["first_visible_frame_ms"] for row in rows),
            "rss_kb": distribution(row["rss_kb"] for row in rows),
        }
    core = json.loads(args.core_summary.read_text(encoding="utf-8"))
    overhead = {}
    for key, on in core["groups"].items():
        if not key.endswith("/on"):
            continue
        prefix = key[:-3]
        off = core["groups"].get(prefix + "/off")
        if off is None:
            continue
        overhead[prefix] = {
            quantile: (
                None if not off["total_ms"][quantile]
                else (on["total_ms"][quantile] / off["total_ms"][quantile] - 1.0) * 100.0
            )
            for quantile in ("p50", "p95", "p99", "max")
        }
    result = {
        "schema_version": 1,
        "core": core,
        "instrumentation_overhead_percent": overhead,
        "pty": pty_summary,
        "cold_start": {
            "minimal": json.loads(args.cold_minimal_summary.read_text(encoding="utf-8")),
            **cold_summary,
        },
        "limitations": {
            "managed_allocation": "unavailable",
            "native_allocation": "unavailable",
            "photon_latency": "unavailable",
            "region_visits": "not-applicable",
            "cache_evictions": "unavailable-current-cache-does-not-evict",
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
