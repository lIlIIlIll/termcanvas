#!/usr/bin/env python3
"""Validate Phase 4B architecture classifications and permanent contracts."""

from __future__ import annotations

import json
import re
import shlex
import sys
import tomllib
from pathlib import Path

import api_contract


ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "architecture/consolidation-baseline.json"
FITNESS = ROOT / "architecture/architecture-fitness.json"
EVIDENCE = ROOT / "architecture/evidence-index.json"
ADR_IDS = [f"{index:03d}" for index in range(1, 11)]


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def dependency_edges(records: list[dict]) -> set[tuple[str, str, str]]:
    top_levels = {
        (record["package"], record["symbol"]): record["stability"]
        for record in records if record["level"] == "top_level"
    }
    edges: set[tuple[str, str, str]] = set()
    for record in records:
        if record["stability"] != "STABLE":
            continue
        for (package, symbol), stability in top_levels.items():
            if package != record["package"] or stability == "STABLE":
                continue
            if re.search(r"\b" + re.escape(symbol) + r"\b", record["signature"]):
                edges.add((
                    f"{record['package']}.{record['qualified_symbol']}",
                    f"{package}.{symbol}",
                    stability,
                ))
    return edges


def validate_api(errors: list[str]) -> tuple[list[dict], dict]:
    metadata = load(api_contract.CLASSIFICATION)
    records = api_contract.classify(api_contract.extract(metadata), metadata)
    errors.extend(api_contract.validate_metadata(records, metadata))
    for path, content in api_contract.rendered_outputs(records, metadata).items():
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            errors.append(f"stale generated API output: {path.relative_to(ROOT)}")
    stable_text = api_contract.STABLE_CONTRACT.read_text(encoding="utf-8") if api_contract.STABLE_CONTRACT.exists() else ""
    for record in records:
        line = api_contract.classified_contract_line(record)
        if record["stability"] in {"INTERNAL", "TEST_ONLY"} and line in stable_text.splitlines():
            errors.append(f"{record['stability']} symbol leaked into stable contract: {record['qualified_symbol']}")
    return records, metadata


def validate_dependencies(records: list[dict], errors: list[str]) -> None:
    baseline = load(BASELINE)
    expected_entries = baseline["known_stable_to_nonstable_dependencies"]
    expected = {
        (entry["source"], entry["target"], entry["target_stability"])
        for entry in expected_entries
    }
    if len(expected) != len(expected_entries):
        errors.append("known stable-to-nonstable dependency entries must be unique")
    for entry in expected_entries:
        if not all(entry.get(field) for field in (
            "owner_phase", "reason", "status", "discovered_by", "removal_condition",
        )):
            errors.append(f"known dependency lacks precise lifecycle ownership: {entry}")
        if entry.get("status") not in {
            "authorized_break", "compatibility_deferred", "newly_discovered_pre_existing",
        }:
            errors.append(f"known dependency has invalid status: {entry}")
        if entry.get("status") == "authorized_break" and not all(entry.get(field) for field in (
            "authorized_boundary", "replacement", "implementation_phase",
        )):
            errors.append(f"authorized break lacks boundary or migration handoff: {entry}")
    actual = dependency_edges(records)
    for edge in sorted(actual - expected):
        errors.append(f"new stable-to-nonstable dependency: {' -> '.join(edge)}")
    for edge in sorted(expected - actual):
        errors.append(f"stale known-dependency allowlist entry: {' -> '.join(edge)}")
    resolved_entries = baseline.get("resolved_stable_to_nonstable_dependencies", [])
    resolved = {
        (entry["source"], entry["target"], entry["target_stability"])
        for entry in resolved_entries
    }
    if len(resolved) != len(resolved_entries):
        errors.append("resolved stable-to-nonstable dependency entries must be unique")
    for entry in resolved_entries:
        if not all(entry.get(field) for field in (
            "status", "authorized_boundary", "implemented_in", "replacement", "evidence",
            "stable_contract_before", "stable_contract_after",
            "experimental_contract_before", "experimental_contract_after",
        )) or entry.get("status") != "resolved":
            errors.append(f"resolved dependency lacks precise closure evidence: {entry}")
    for edge in sorted(actual & resolved):
        errors.append(f"resolved stable-to-nonstable dependency returned: {' -> '.join(edge)}")
    for edge in sorted(expected & resolved):
        errors.append(f"dependency cannot be both active and resolved: {' -> '.join(edge)}")


def validate_retired_api_groups(records: list[dict], errors: list[str]) -> None:
    """Keep evidence-owned retired API groups out of the current inventory."""
    baseline = load(BASELINE)
    observability = baseline.get("api_contract_observability", {})
    if not all(observability.get(field) for field in (
        "format_version", "status", "production_source_delta",
        "pre_enum_inventory_stable_hash", "enum_aware_stable_hash",
        "stable_enum_count", "stable_enum_constructor_count",
    )):
        errors.append("API contract observability migration metadata is incomplete")
    if observability.get("production_source_delta") != "none":
        errors.append("API contract observability migration must not claim a production source delta")
    current = {
        f"{record['package']}.{record['qualified_symbol']}"
        for record in records if record["level"] == "top_level"
    }
    for group in baseline.get("retired_api_groups", []):
        if not all(group.get(field) for field in ("id", "phase", "qualified_symbols", "reason", "revisit")):
            errors.append(f"incomplete retired API group: {group}")
            continue
        for symbol in group["qualified_symbols"]:
            if symbol in current:
                errors.append(f"retired API returned to current surface: {group['id']} -> {symbol}")


def validate_experimental_portfolio(
    records: list[dict], metadata: dict, errors: list[str],
) -> tuple[int, int]:
    """Reconcile the current EXPERIMENTAL API with lifecycle ownership.

    Families may partition a shared classification rule with an explicit
    ``symbols`` list.  A family without that list owns the remainder of its
    rules after all explicit partitions have been removed.  This keeps the
    check metadata-driven while still supporting the existing mixed widget and
    editor rules.
    """
    baseline = load(BASELINE)
    portfolio = baseline.get("experimental_api_portfolio", {})
    families = portfolio.get("families", [])
    family_ids = [family.get("id", "") for family in families]
    if not families:
        errors.append("experimental lifecycle portfolio is missing")
        return 0, 0
    if any(not family_id for family_id in family_ids) or len(set(family_ids)) != len(family_ids):
        errors.append("experimental lifecycle family ids must be present and unique")

    rule_by_id = {rule.get("id"): rule for rule in metadata.get("rules", [])}
    required_fields = (
        "id", "rules", "top_level", "contract_entries", "owner", "decision",
        "adoption", "reason", "revisit",
    )
    for family in families:
        missing = [field for field in required_fields if not family.get(field)]
        if missing:
            errors.append(f"experimental lifecycle family {family.get('id')} lacks {missing}")
        for rule_id in family.get("rules", []):
            rule = rule_by_id.get(rule_id)
            if rule is None:
                errors.append(f"experimental lifecycle family {family.get('id')} names missing rule {rule_id}")
                continue
            if rule.get("stability") != "EXPERIMENTAL":
                errors.append(f"experimental lifecycle family {family.get('id')} owns nonexperimental rule {rule_id}")
            if not all(rule.get(field) for field in ("owner", "promotion_condition", "sunset_condition")):
                errors.append(f"experimental lifecycle rule lacks owner/promotion/sunset policy: {rule_id}")

    def owns(family: dict, record: dict) -> bool:
        if record.get("classification_rule") not in family.get("rules", []):
            return False
        symbols = family.get("symbols")
        if symbols is not None:
            return record.get("owner_symbol") in symbols
        return not any(
            other.get("symbols") is not None
            and record.get("classification_rule") in other.get("rules", [])
            and record.get("owner_symbol") in other.get("symbols", [])
            for other in families
        )

    experimental = [record for record in records if record["stability"] == "EXPERIMENTAL"]
    top_level = [record for record in experimental if record["level"] == "top_level"]
    for record in experimental:
        owners = [family["id"] for family in families if owns(family, record)]
        if len(owners) != 1:
            errors.append(
                "experimental lifecycle ownership must be exactly one: "
                f"{record['package']}.{record['qualified_symbol']} -> {owners}"
            )

    for family in families:
        actual_top = sum(owns(family, record) for record in top_level)
        actual_entries = sum(owns(family, record) for record in experimental)
        if actual_top != family.get("top_level"):
            errors.append(
                f"experimental lifecycle top-level count mismatch for {family.get('id')}: "
                f"metadata={family.get('top_level')} actual={actual_top}"
            )
        if actual_entries != family.get("contract_entries"):
            errors.append(
                f"experimental lifecycle entry count mismatch for {family.get('id')}: "
                f"metadata={family.get('contract_entries')} actual={actual_entries}"
            )

    expected_totals = {
        "family_total": len(families),
        "top_level_total": len(top_level),
        "contract_entry_total": len(experimental),
    }
    for field, actual in expected_totals.items():
        if portfolio.get(field) != actual:
            errors.append(
                f"experimental lifecycle {field} mismatch: "
                f"metadata={portfolio.get(field)} actual={actual}"
            )

    distribution = portfolio.get("distribution", {})
    for decision, expected in distribution.items():
        owned = [family for family in families if family.get("decision") == decision]
        actual = {
            "families": len(owned),
            "top_level": sum(family.get("top_level", 0) for family in owned),
        }
        if expected != actual:
            errors.append(
                f"experimental lifecycle distribution mismatch for {decision}: "
                f"metadata={expected} actual={actual}"
            )
    undistributed = sorted({family.get("decision") for family in families} - set(distribution))
    if undistributed:
        errors.append(f"experimental lifecycle decisions missing from distribution: {undistributed}")
    return len(families), len(top_level)


def validate_forbidden_symbol_dependencies(errors: list[str]) -> None:
    """Check explicit, metadata-owned package/type boundary decisions.

    This is a narrow exact-symbol source guard, not a general Cangjie parser or
    a permanent banned-name list. Each relationship must carry an owning phase
    and architectural reason in the checked-in consolidation baseline.
    """
    baseline = load(BASELINE)
    for entry in baseline.get("forbidden_symbol_dependencies", []):
        if not all(entry.get(field) for field in (
            "source_path", "source_package", "target_package", "target_symbol",
            "owner_phase", "reason",
        )):
            errors.append(f"incomplete forbidden symbol dependency: {entry}")
            continue
        source_root = ROOT / entry["source_path"]
        if not source_root.is_dir():
            errors.append(f"forbidden dependency source path is missing: {entry['source_path']}")
            continue
        symbol = entry["target_symbol"]
        for path in sorted(source_root.glob("*.cj")):
            if re.search(r"\b" + re.escape(symbol) + r"\b", path.read_text(encoding="utf-8")):
                errors.append(
                    f"forbidden package/type dependency: {entry['source_package']} -> "
                    f"{entry['target_package']}.{symbol} in {path.relative_to(ROOT)}"
                )


def validate_frame_boundary(errors: list[str]) -> None:
    """Keep the stable Frame implementation independent of retained experiments.

    This is deliberately an explicit boundary check, not a claimed general
    Cangjie dependency parser. Signature dependencies remain covered by the
    classified API graph above.
    """
    source = (ROOT / "packages/core/src/terminal.cj").read_text(encoding="utf-8")
    start = source.find("public class Frame {")
    end = source.find("public enum RenderMode", start)
    if start < 0 or end < 0:
        errors.append("cannot locate the stable Frame source boundary")
        return
    frame_source = source[start:end]
    forbidden = (
        "Component", "RuntimeComponent", "ComponentNode", "ComponentHost",
        "ViewNode", "StyleSheet", "ComputedStyle", "Css",
    )
    for symbol in forbidden:
        if re.search(r"\b" + re.escape(symbol) + r"\b", frame_source):
            errors.append(f"stable Frame implementation references nonstable rendering model: {symbol}")


def manifest_dependencies(path: Path) -> set[str]:
    with path.open("rb") as handle:
        document = tomllib.load(handle)
    return set(document.get("dependencies", {}))


def validate_component_package_boundary(errors: list[str]) -> None:
    """Validate the retired component package boundary.

    Cjpm manifests are the authoritative package dependency source here. Exact
    package and import checks prevent the retired optional lifecycle runtime
    from silently returning without banning unrelated Component-prefixed names.
    """
    component_root = ROOT / "packages/component_experimental"
    if component_root.exists():
        errors.append("retired component experimental package is present")

    for manifest in sorted((ROOT / "packages").glob("*/cjpm.toml")):
        if "component_experimental" in manifest_dependencies(manifest):
            errors.append(f"package depends on retired component experimental: {manifest.relative_to(ROOT)}")

    baseline = load(BASELINE)
    for example in baseline.get("examples", []):
        manifest = ROOT / example["path"] / "cjpm.toml"
        if manifest.exists() and "component_experimental" in manifest_dependencies(manifest):
            errors.append(f"example depends on retired component experimental: {example['path']}")

    production_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "packages").glob("*/src/*.cj"))
        if not path.name.endswith("_test.cj")
    )
    if re.search(r"\b(?:import|public import)\s+component_experimental\b", production_sources):
        errors.append("production source imports or re-exports retired component experimental")


def validate_retained_view_package_boundary(errors: list[str]) -> None:
    """Validate the retired retained ViewNode/CSS package boundary.

    Exact package and manifest checks prevent the retired optional architecture
    from silently returning without banning general View/CSS-prefixed names.
    """
    retained_root = ROOT / "packages/retained_view_experimental"
    if retained_root.exists():
        errors.append("retired retained view experimental package is present")

    for manifest in sorted((ROOT / "packages").glob("*/cjpm.toml")):
        if "retained_view_experimental" in manifest_dependencies(manifest):
            errors.append(f"package depends on retired retained view experimental: {manifest.relative_to(ROOT)}")

    baseline = load(BASELINE)
    for example in baseline.get("examples", []):
        manifest = ROOT / example["path"] / "cjpm.toml"
        if manifest.exists() and "retained_view_experimental" in manifest_dependencies(manifest):
            errors.append(f"example depends on retired retained view experimental: {example['path']}")

    production_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "packages").glob("*/src/*.cj"))
        if not path.name.endswith("_test.cj")
    )
    if re.search(r"\b(?:import|public import)\s+retained_view_experimental\b", production_sources):
        errors.append("production source imports or re-exports retired retained view experimental")


def validate_fitness(errors: list[str]) -> None:
    manifest = load(FITNESS)
    allowed_tiers = {"fast", "architecture", "release", "microbenchmark"}
    ids: set[str] = set()
    for gate in manifest["gates"]:
        gate_id = gate.get("id", "")
        if not gate_id or gate_id in ids:
            errors.append(f"invalid or duplicate fitness id: {gate_id}")
        ids.add(gate_id)
        if gate.get("tier") not in allowed_tiers:
            errors.append(f"{gate_id}: invalid fitness tier")
        if not gate.get("contract") or not gate.get("command"):
            errors.append(f"{gate_id}: missing contract or command")
        command = shlex.split(gate.get("command", ""))
        if gate.get("repository", "termcanvas") == "termcanvas" and command:
            executable = ROOT / command[0]
            if "/" in command[0] and not executable.exists():
                errors.append(f"{gate_id}: command path does not exist: {command[0]}")
        for evidence in gate.get("evidence_paths", []):
            if not (ROOT / evidence).exists():
                errors.append(f"{gate_id}: evidence path does not exist: {evidence}")
    phases = {entry.get("phase") for entry in manifest.get("proof_only_archive", [])}
    expected_phases = {"0", "0.5", "1A", "1B", "2A", "2B", "2C", "3A", "3B", "3B.5", "3C", "3D"}
    if phases != expected_phases:
        errors.append(f"proof retention classification mismatch: {sorted(phases)}")


def validate_evidence_and_handoffs(errors: list[str]) -> None:
    evidence = load(EVIDENCE)
    decisions = evidence.get("decisions", [])
    if not decisions or any(item.get("result") not in {"GO", "STOP"} for item in decisions):
        errors.append("evidence index must contain explicit GO/STOP decisions")
    for item in decisions:
        if not all(item.get(field) for field in ("id", "phase", "evidence", "revisit")):
            errors.append(f"incomplete evidence decision: {item.get('id')}")
    baseline = load(BASELINE)
    allowed_example_classes = {"recommended", "feature_demo", "experimental", "proof", "legacy"}
    for example in baseline.get("examples", []):
        if example.get("classification") not in allowed_example_classes:
            errors.append(f"invalid example classification: {example}")
        if not (ROOT / example["path"]).exists():
            errors.append(f"classified example path does not exist: {example['path']}")
    for fixture in baseline.get("proof_fixtures", []):
        if fixture.get("classification") not in {"microbenchmark", "architecture_regression", "proof_only"}:
            errors.append(f"invalid proof fixture classification: {fixture}")
        if not (ROOT / fixture.get("path", "")).exists():
            errors.append(f"classified proof fixture path does not exist: {fixture.get('path', '')}")
        if not fixture.get("owner") or not fixture.get("revisit") or not isinstance(fixture.get("permanent"), bool):
            errors.append(f"proof fixture lacks owner, permanence, or revisit policy: {fixture}")
    required_focus_ownership = {"FocusManager"}
    observed_focus_ownership: set[str] = set()
    for entry in baseline.get("focus_modal_ownership", []):
        symbols = entry.get("symbols", [])
        if not symbols:
            errors.append(f"focus/modal ownership entry lacks symbols: {entry}")
        for symbol in symbols:
            if symbol in observed_focus_ownership:
                errors.append(f"duplicate focus/modal ownership: {symbol}")
            observed_focus_ownership.add(symbol)
        if entry.get("classification") not in {"stable", "experimental", "internal", "test_only"}:
            errors.append(f"invalid focus/modal classification: {entry}")
        if not all(entry.get(field) for field in ("owner", "disposition", "revisit_condition")):
            errors.append(f"incomplete focus/modal ownership entry: {entry}")
    if observed_focus_ownership != required_focus_ownership:
        errors.append(
            "focus/modal ownership coverage mismatch: "
            f"missing={sorted(required_focus_ownership - observed_focus_ownership)}, "
            f"extra={sorted(observed_focus_ownership - required_focus_ownership)}"
        )
    if set(baseline.get("phase_handoffs", {})) != {"4C", "4D", "4E", "4F", "4G"}:
        errors.append("consolidation handoffs must cover Phase 4C through 4G")


def validate_adrs(errors: list[str]) -> None:
    adr_root = ROOT / "docs/adr"
    for adr_id in ADR_IDS:
        matches = sorted(adr_root.glob(f"{adr_id}-*.md"))
        if len(matches) != 1:
            errors.append(f"expected exactly one ADR-{adr_id}, found {len(matches)}")
            continue
        text = matches[0].read_text(encoding="utf-8")
        for heading in ("Status", "Context", "Decision", "Evidence", "Consequences", "Rejected alternatives", "Revisit conditions", "Fitness functions"):
            if f"## {heading}" not in text:
                errors.append(f"{matches[0].name}: missing {heading} section")
        if "Accepted" not in text:
            errors.append(f"{matches[0].name}: status is not Accepted")


def main() -> int:
    errors: list[str] = []
    records, metadata = validate_api(errors)
    validate_dependencies(records, errors)
    validate_retired_api_groups(records, errors)
    lifecycle_families, lifecycle_top_level = validate_experimental_portfolio(records, metadata, errors)
    validate_forbidden_symbol_dependencies(errors)
    validate_frame_boundary(errors)
    validate_component_package_boundary(errors)
    validate_retained_view_package_boundary(errors)
    validate_fitness(errors)
    validate_evidence_and_handoffs(errors)
    validate_adrs(errors)
    if errors:
        print("architecture validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    top = [record for record in records if record["level"] == "top_level"]
    counts = {tier: sum(1 for record in top if record["stability"] == tier) for tier in ("STABLE", "EXPERIMENTAL", "INTERNAL", "TEST_ONLY")}
    print(
        "architecture contracts ok: "
        f"{len(top)} production top-level declarations, "
        + ", ".join(f"{tier.lower()}={count}" for tier, count in counts.items())
        + f", unclassified=0, lifecycle={lifecycle_families}/{lifecycle_top_level}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
