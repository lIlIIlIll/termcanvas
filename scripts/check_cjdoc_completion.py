#!/usr/bin/env python3
"""Require complete application docs and source-matched native example reports."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from api_contract import ROOT, load_json
from audit_cjdoc import audit
from cjdoc_examples import load_examples
from generate_cjdoc import MARKER, sha256
from native_sdk import SDK_VERSION

TARGETS = {"linux", "macos", "windows"}
HASH = re.compile(r"^[0-9a-f]{64}$")


def check(portal: Path, reports: list[Path]) -> dict:
    summary = audit(portal)
    counts = summary["counts"]
    total = counts.get("application_declarations", 0)
    failures = []
    if summary["scope_partial"] or total == 0:
        failures.append("portal does not cover all configured packages and platforms")
    for name in ("mapped", "chinese_summary", "parameters_documented", "returns_documented", "shared_example_linked"):
        if counts.get(name, 0) != total:
            failures.append(f"{name}: {counts.get(name, 0)}/{total}")
    marker = load_json(portal / MARKER)
    inventory = load_json(portal / "api-inventory.json")
    scenarios, _ = load_examples(inventory)
    if not scenarios:
        failures.append("no shared examples")
    by_target: dict[str, dict] = {}
    report_hashes = {}
    for path in reports:
        report = load_json(path)
        target = report.get("platform")
        if target not in TARGETS or target in by_target:
            failures.append(f"unknown or duplicate native report platform: {target}")
            continue
        by_target[target] = report
        report_hashes[target] = sha256(path)
    reference_sources = None
    for target in sorted(TARGETS):
        report = by_target.get(target)
        if report is None:
            failures.append(f"missing native example report: {target}")
            continue
        if report.get("format_version") != 1 or report.get("selected") is not False:
            failures.append(f"incomplete native example report: {target}")
        sources = report.get("sources")
        if not isinstance(sources, dict):
            failures.append(f"missing source identities: {target}")
            continue
        digest = hashlib.sha256(json.dumps(sources, sort_keys=True).encode("utf-8")).hexdigest()
        if report.get("sources_sha256") != digest or any(sources.get(name) != value for name, value in marker["sources"].items()):
            failures.append(f"source identities do not match portal: {target}")
        if reference_sources is None:
            reference_sources = sources
        elif sources != reference_sources:
            failures.append(f"native reports use different source identities: {target}")
        sdk = report.get("sdk") or {}
        if target == "linux" and any(sdk.get(key) != (marker.get("sdk") or {}).get(key)
                                     for key in ("cjc_sha256", "cjpm_sha256", "runtime_sha256")):
            failures.append("Linux documentation and example SDK identities differ")
        version = re.compile(r"(?<![0-9.])" + re.escape(SDK_VERSION) + r"(?![0-9.])")
        if (not version.search(sdk.get("cjc_version", "")) or not version.search(sdk.get("cjpm_version", "")) or
            any(not HASH.fullmatch(sdk.get(key, "")) for key in ("cjc_sha256", "cjpm_sha256", "runtime_sha256"))):
            failures.append(f"unqualified SDK record: {target}")
        results = report.get("results")
        if not isinstance(results, list) or len(results) != len(scenarios):
            failures.append(f"incomplete scenario results: {target}")
            continue
        results_by_id = {item.get("id"): item for item in results if isinstance(item, dict)}
        if len(results_by_id) != len(scenarios):
            failures.append(f"duplicate or invalid scenario result: {target}")
            continue
        for scenario in scenarios:
            item = results_by_id.get(scenario["id"])
            expected = "passed" if target in scenario["platforms"] else "not_applicable"
            if (item is None or item.get("status") != expected or item.get("source") != scenario["source"] or
                item.get("source_sha256") != sha256(ROOT / scenario["source"])):
                failures.append(f'scenario {scenario["id"]} is not verified on {target}')
    return {"format_version": 1, "status": "failed" if failures else "passed", "failures": failures,
            "counts": counts, "portal_marker_sha256": sha256(portal / MARKER), "reports_sha256": report_hashes}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("portal", type=Path)
    parser.add_argument("--report", action="append", type=Path, default=[], help="native example result JSON")
    parser.add_argument("--attestation", type=Path, help="new output JSON file for a passing check")
    args = parser.parse_args()
    try:
        result = check(args.portal, args.report)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if result["status"] != "passed":
            return 1
        if args.attestation is not None:
            with args.attestation.open("x", encoding="utf-8") as stream:
                json.dump(result, stream, ensure_ascii=False, indent=2)
                stream.write("\n")
        return 0
    except (OSError, KeyError, ValueError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
