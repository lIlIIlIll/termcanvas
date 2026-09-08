#!/usr/bin/env python3
"""Run and summarize the reproducible Step-0 architecture-proof workloads."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "benchmarks/architecture-proof-step0/manifest.json"
CORE_BINARY = ROOT / "benchmarks/architecture-proof-step0/fixture/target/release/bin/main"
CORE_WORKLOADS = (
    "scroll_line",
    "scroll_page",
    "scroll_continuous",
    "stream_a_no_wrap",
    "stream_b_wrap_cross",
    "stream_c_complete_line",
    "stream_d_new_item",
    "resize_small_width_oscillation",
    "resize_large_width_jump",
    "resize_huge_width_extremes",
    "resize_manual_width_extremes",
    "resize_continuous_width",
    "resize_height_only",
    "resize_width_height",
)


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * fraction + 0.999999)))
    return ordered[index]


def distribution(values: Iterable[float], p99_min_samples: int) -> dict[str, float | int | None]:
    samples = list(values)
    if not samples:
        return {"n": 0, "p50": None, "p95": None, "p99": None, "max": None}
    return {
        "n": len(samples),
        "p50": statistics.median(samples),
        "p95": percentile(samples, 0.95),
        "p99": percentile(samples, 0.99) if len(samples) >= p99_min_samples else None,
        "max": max(samples),
    }


def repository_commit() -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True, check=False
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return result.stdout.strip()


def git_identifier() -> str:
    commit = repository_commit()
    if commit is None:
        raise SystemExit("cannot identify benchmark source checkout")
    if not CORE_BINARY.is_file():
        raise SystemExit(f"missing benchmark binary: {CORE_BINARY}; build its cjpm package first")
    binary_digest = hashlib.sha256(CORE_BINARY.read_bytes()).hexdigest()[:16]
    return commit + "+bin:" + binary_digest


def summary_tool_identity() -> dict[str, str | None]:
    script = Path(__file__).resolve()
    return {
        "repository_commit": repository_commit(),
        "script": script.relative_to(ROOT).as_posix(),
        "script_sha256": hashlib.sha256(script.read_bytes()).hexdigest(),
    }


def load_acquisition_provenance(output: Path) -> dict[str, Any]:
    path = output / "provenance.json"
    if not path.is_file():
        raise SystemExit(f"missing acquisition provenance: {path}")
    try:
        provenance = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"invalid acquisition provenance {path}: {error}") from error
    build_identifier = provenance.get("build_identifier")
    if not isinstance(build_identifier, str) or not build_identifier:
        raise SystemExit(f"acquisition provenance lacks build_identifier: {path}")
    return provenance


def validate_raw_build_identifiers(output: Path, expected: str) -> None:
    for name, required in (("core_samples.jsonl", True), ("core_setup.jsonl", False)):
        path = output / name
        if not path.is_file():
            if required:
                raise SystemExit(f"missing raw benchmark data: {path}")
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                raise SystemExit(f"invalid raw record {path}:{line_number}: {error}") from error
            actual = record.get("build_identifier")
            if actual != expected:
                raise SystemExit(
                    f"raw build_identifier mismatch at {path}:{line_number}: "
                    f"expected {expected!r}, got {actual!r}"
                )


def run_core(
    output: Path,
    histories: tuple[int, ...],
    iterations: int,
    warmup: int,
    modes: tuple[str, ...],
    workloads: tuple[str, ...],
    build_id: str,
) -> None:
    if not CORE_BINARY.is_file():
        raise SystemExit(f"missing benchmark binary: {CORE_BINARY}; build its cjpm package first")
    raw_path = output / "core_samples.jsonl"
    setup_path = output / "core_setup.jsonl"
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    with raw_path.open("w", encoding="utf-8") as raw, setup_path.open("w", encoding="utf-8") as setups:
        for workload in workloads:
            for history in histories:
                for mode in modes:
                    env = os.environ.copy()
                    env.update(
                        {
                            "STEP0_WORKLOAD": workload,
                            "STEP0_HISTORY": str(history),
                            "STEP0_ITERATIONS": str(iterations),
                            "STEP0_WARMUP": str(warmup),
                            "STEP0_METRICS": mode,
                            "STEP0_BUILD_ID": build_id,
                            "STEP0_WIDTH": "100",
                            "STEP0_HEIGHT": "28",
                        }
                    )
                    completed = subprocess.run(
                        [str(CORE_BINARY)], cwd=ROOT, env=env, text=True,
                        capture_output=True, check=True,
                    )
                    for line in completed.stdout.splitlines():
                        record = json.loads(line)
                        if record.get("kind") == "sample":
                            raw.write(json.dumps(record, sort_keys=True) + "\n")
                        elif record.get("kind") == "setup":
                            record.update({"metrics_mode": mode, "build_identifier": build_id})
                            setups.write(json.dumps(record, sort_keys=True) + "\n")
                    raw.flush()
                    setups.flush()
                    print(f"core {workload} history={history} metrics={mode}", flush=True)


def summarize_core(output: Path, p99_min_samples: int) -> dict[str, Any]:
    raw_path = output / "core_samples.jsonl"
    rows = [json.loads(line) for line in raw_path.read_text(encoding="utf-8").splitlines() if line]
    summaries: dict[str, Any] = {}
    keys = sorted({(row["benchmark"], row["history_count"], row["metrics_mode"]) for row in rows})
    for benchmark, history, mode in keys:
        selected = [
            row for row in rows
            if row["benchmark"] == benchmark
            and row["history_count"] == history
            and row["metrics_mode"] == mode
        ]
        key = f"{benchmark}/{history}/{mode}"
        summaries[key] = {
            "total_ms": distribution(
                (row["stage_timings"]["total_nanos"] / 1_000_000 for row in selected),
                p99_min_samples,
            ),
            "render_ms": distribution(
                (row["stage_timings"]["render_nanos"] / 1_000_000 for row in selected),
                p99_min_samples,
            ),
            "diff_ms": distribution(
                (row["stage_timings"]["diff_nanos"] / 1_000_000 for row in selected),
                p99_min_samples,
            ),
            "write_ms": distribution(
                (row["stage_timings"]["write_nanos"] / 1_000_000 for row in selected),
                p99_min_samples,
            ),
            "counters": {
                name: distribution((row["counters"][name] for row in selected), p99_min_samples)
                for name in selected[0]["counters"]
            },
        }
    return {"sample_count": len(rows), "groups": summaries}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--histories", default="100,1000,10000,100000")
    parser.add_argument("--iterations", type=int, default=120)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--metrics-modes", default="off,on")
    parser.add_argument("--workloads", default=",".join(CORE_WORKLOADS))
    parser.add_argument("--summarize-only", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    histories = tuple(int(value) for value in args.histories.split(",") if value)
    modes = tuple(value for value in args.metrics_modes.split(",") if value)
    workloads = tuple(value for value in args.workloads.split(",") if value)
    unknown = sorted(set(workloads) - set(CORE_WORKLOADS))
    if unknown:
        raise SystemExit("unknown core workloads: " + ", ".join(unknown))
    if args.iterations <= 0 or args.warmup < 0:
        raise SystemExit("iterations must be positive and warmup non-negative")
    args.output.mkdir(parents=True, exist_ok=True)
    if args.summarize_only:
        provenance = load_acquisition_provenance(args.output)
    else:
        build_id = git_identifier()
        provenance = {
            "schema_version": 1,
            "manifest": str(MANIFEST.relative_to(ROOT)),
            "build_identifier": build_id,
            "sample_order_origin": 1,
            "clock": "Cangjie MonoTime",
            "generated_unix_ns": time.time_ns(),
            "histories": histories,
            "iterations": args.iterations,
            "warmup": args.warmup,
            "metrics_modes": modes,
            "workloads": workloads,
            "managed_allocation": "unavailable",
            "native_allocation": "unavailable",
        }
        (args.output / "provenance.json").write_text(
            json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        run_core(args.output, histories, args.iterations, args.warmup, modes, workloads, build_id)
    build_id = provenance["build_identifier"]
    validate_raw_build_identifiers(args.output, build_id)
    summary = summarize_core(args.output, int(manifest["sample_policy"]["p99_min_samples"]))
    (args.output / "core_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    summary_provenance = {
        "schema_version": 1,
        "source_provenance": "provenance.json",
        "source_build_identifier": build_id,
        "summarizer": summary_tool_identity(),
        "generated_unix_ns": time.time_ns(),
    }
    (args.output / "summary_provenance.json").write_text(
        json.dumps(summary_provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"raw={args.output / 'core_samples.jsonl'}")
    print(f"summary={args.output / 'core_summary.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
