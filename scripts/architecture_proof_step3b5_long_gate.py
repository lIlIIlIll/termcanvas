#!/usr/bin/env python3
"""Repeat the real consumer long-transcript aggregate gate and retain raw results."""

import argparse
import hashlib
import json
import os
import re
import statistics
import subprocess
import time
from pathlib import Path


LONG_RE = re.compile(
    r"tui long transcript frames=(\d+) render=(\d+)ms max=(\d+)ms documents=(\d+)"
)
GATE_RE = re.compile(
    r"tui long transcript gates configured=(\d+) transcript_expected=(\d+) "
    r"transcript_actual=(\d+) content_preserved=(true|false) "
    r"documents_expected<=(\d+) documents_actual=(\d+)"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * fraction)))
    return ordered[index]


def distribution(values: list[float]) -> dict[str, float | int | None]:
    return {
        "n": len(values),
        "p50": statistics.median(values) if values else None,
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99) if len(values) >= 100 else None,
        "max": max(values) if values else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--history", type=int, default=100000)
    parser.add_argument("--metrics", choices=("off", "on"), default="off")
    parser.add_argument("--frame-budget-ms", type=int, default=0)
    args = parser.parse_args()
    binary = args.binary.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for run_id in range(1, args.runs + 1):
        env = os.environ.copy()
        env.update({
            "AGENT_TUI_HEADLESS": "1",
            "AGENT_TUI_HEADLESS_LONG_PERF": "1",
            "OMP_CJ_TUI_PERF_DATA_COUNT": str(args.history),
            "OMP_CJ_TUI_METRICS": "1" if args.metrics == "on" else "0",
            "CJ_TUI_FRAME_COALESCE_MS": str(args.frame_budget_ms),
        })
        started = time.monotonic_ns()
        completed = subprocess.run(
            [str(binary)], env=env, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=120, check=False,
        )
        wall_ms = (time.monotonic_ns() - started) / 1_000_000
        long_match = LONG_RE.search(completed.stdout)
        gate_match = GATE_RE.search(completed.stdout)
        record = {
            "run_id": run_id,
            "returncode": completed.returncode,
            "wall_ms": wall_ms,
            "frames": int(long_match.group(1)) if long_match else None,
            "render_ms": int(long_match.group(2)) if long_match else None,
            "max_render_ms": int(long_match.group(3)) if long_match else None,
            "documents": int(long_match.group(4)) if long_match else None,
            "configured_cards": int(gate_match.group(1)) if gate_match else None,
            "transcript_expected": int(gate_match.group(2)) if gate_match else None,
            "transcript_actual": int(gate_match.group(3)) if gate_match else None,
            "content_preserved": gate_match.group(4) == "true" if gate_match else None,
            "documents_expected": int(gate_match.group(5)) if gate_match else None,
            "documents_actual": int(gate_match.group(6)) if gate_match else None,
            "differential": "FAIL" if "selective/full differential failed" in completed.stdout else (
                "PASS" if long_match else "NOT_REACHED"
            ),
            "stdout": completed.stdout,
        }
        records.append(record)
        print(f"long-gate {args.metrics} run={run_id} exit={completed.returncode}")
    raw_path = args.output / f"long-gate-{args.metrics}.jsonl"
    raw_path.write_text("".join(json.dumps(record, sort_keys=True) + "\n" for record in records))
    summary = {
        "binary": str(binary),
        "binary_sha256": sha256(binary),
        "history": args.history,
        "metrics": args.metrics,
        "frame_budget_ms": args.frame_budget_ms,
        "runs": args.runs,
        "exit_codes": [record["returncode"] for record in records],
        "differential": [record["differential"] for record in records],
        "wall_ms": distribution([record["wall_ms"] for record in records]),
        "render_ms": distribution([record["render_ms"] for record in records if record["render_ms"] is not None]),
        "max_render_ms": distribution([record["max_render_ms"] for record in records if record["max_render_ms"] is not None]),
        "documents": distribution([record["documents"] for record in records if record["documents"] is not None]),
        "gates": [{key: record[key] for key in (
            "run_id", "configured_cards", "transcript_expected", "transcript_actual", "content_preserved",
            "documents_expected", "documents_actual", "returncode", "differential"
        )} for record in records],
    }
    (args.output / f"long-gate-summary-{args.metrics}.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n"
    )
    return 0 if all(record["returncode"] == 0 for record in records) else 1


if __name__ == "__main__":
    raise SystemExit(main())
