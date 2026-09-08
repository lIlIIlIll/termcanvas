#!/usr/bin/env python3
"""Reduce Step 0.5 raw summaries into a compact, machine-readable report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def timing(summary: dict[str, Any], key: str, field: str) -> dict[str, Any]:
    return summary["groups"][key]["timings"][field]


def counter(summary: dict[str, Any], key: str, field: str) -> dict[str, Any]:
    return summary["groups"][key]["counters"][field]


def core_counter(summary: dict[str, Any], key: str, field: str) -> dict[str, Any]:
    return summary["groups"][key]["counters"][field]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--product-dir", type=Path, required=True)
    parser.add_argument("--core-summary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    off = load(args.product_dir / "summary-off.json")
    on = load(args.product_dir / "summary-on.json")
    repeat = load(args.product_dir / "summary-off_repeat.json")
    core = load(args.core_summary)

    selected = [
        "typing_ascii/100000", "typing_cjk/100000", "backspace/100000",
        "cursor_left_right/100000", "key_repeat_up_down/100000",
        "scroll_line/100", "scroll_line/1000", "scroll_line/10000", "scroll_line/100000",
        "scroll_page/100", "scroll_page/100000", "scroll_continuous/100", "scroll_continuous/100000",
        "stream_a_existing_no_wrap/100000", "stream_b_existing_wrap/100000",
        "stream_c_complete_line/100000", "stream_d_append_item/100000",
        "resize_small_width/100000", "resize_large_width/100000",
        "resize_continuous_width/100000", "resize_height_only/100000",
        "resize_width_height/100000", "overlay_open/100000",
        "overlay_close/100000", "overlay_switch/100000",
    ]
    stages = [
        "update_ms", "screen_preparation_ms", "transcript_render_ms",
        "activity_render_ms", "queue_todo_render_ms", "composer_render_ms",
        "overlay_render_ms", "product_other_ms", "core_render_ms", "diff_ms",
        "write_ms", "total_ms",
    ]
    counters = [
        "metadata_touches", "height_index_reset_entries", "height_index_update_calls",
        "document_requests", "documents_materialized", "wrap_input_bytes",
        "buffer_cell_attempts", "buffer_cell_writes", "diff_cells", "diff_spans", "ansi_bytes",
    ]
    result: dict[str, Any] = {
        "latency_off": {key: {field: timing(off, key, field) for field in stages} for key in selected},
        "attribution_on": {key: {field: counter(on, key, field) for field in counters} for key in selected},
        "append_scaling": {}, "resize_scaling": {}, "correlation": {}, "perturbation": {},
    }
    for history in (100, 1000, 10000, 100000):
        append_key = f"stream_d_append_item/{history}"
        resize_key = f"resize_small_width/{history}"
        result["append_scaling"][str(history)] = {
            "off_total_ms": timing(off, append_key, "total_ms"),
            "on_metadata_touches": counter(on, append_key, "metadata_touches"),
            "on_height_index_reset_entries": counter(on, append_key, "height_index_reset_entries"),
        }
        result["resize_scaling"][str(history)] = {
            "off_total_ms": timing(off, resize_key, "total_ms"),
            "on_metadata_touches": counter(on, resize_key, "metadata_touches"),
            "on_height_index_reset_entries": counter(on, resize_key, "height_index_reset_entries"),
        }
    mappings = {
        "scroll_line": ("scroll_line", "scroll_line"),
        "stream_a": ("stream_a_no_wrap", "stream_a_existing_no_wrap"),
        "stream_b": ("stream_b_wrap_cross", "stream_b_existing_wrap"),
        "stream_c": ("stream_c_complete_line", "stream_c_complete_line"),
        "stream_d": ("stream_d_new_item", "stream_d_append_item"),
        "resize_small": ("resize_small_width_oscillation", "resize_small_width"),
        "resize_large": ("resize_large_width_jump", "resize_large_width"),
    }
    for label, (core_name, product_name) in mappings.items():
        result["correlation"][label] = {}
        for history in (100, 1000, 10000, 100000):
            product_key = f"{product_name}/{history}"
            if product_key not in on["groups"]:
                continue
            core_key = f"{core_name}/{history}/on"
            result["correlation"][label][str(history)] = {
                "core_metadata_touches_p50": core_counter(core, core_key, "metadata_touches")["p50"],
                "product_metadata_touches_p50": counter(on, product_key, "metadata_touches")["p50"],
                "core_wrap_input_bytes_p50": core_counter(core, core_key, "wrap_input_bytes")["p50"],
                "product_wrap_input_bytes_p50": counter(on, product_key, "wrap_input_bytes")["p50"],
            }
    for key in repeat["groups"]:
        result["perturbation"][key] = {
            "off": timing(off, key, "total_ms"), "on": timing(on, key, "total_ms"),
            "off_repeat": timing(repeat, key, "total_ms"),
        }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
