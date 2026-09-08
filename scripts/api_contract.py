#!/usr/bin/env python3
"""Extract and classify cj_tui's source-level public API.

This is intentionally a source contract, not an ABI parser. It extracts
production declarations using explicit source roots, assigns architecture
stability from architecture/api-classification.json, and emits deterministic
generated views. Language visibility and architecture stability are separate.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLASSIFICATION = ROOT / "architecture/api-classification.json"
INVENTORY = ROOT / "docs/api-inventory.json"
LEGACY_CONTRACT = ROOT / "docs/api-contract-v1.txt"
LEGACY_INDEX = ROOT / "docs/api-index.txt"
STABLE_CONTRACT = ROOT / "docs/stable-api-contract.txt"
EXPERIMENTAL_CONTRACT = ROOT / "docs/experimental-api-contract.txt"

TOP_LEVEL_RE = re.compile(
    r"^public\s+(?:(?:open|abstract)\s+)?(class|struct|enum|interface|func|type)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)
PUBLIC_RE = re.compile(
    r"^(?P<indent>\s*)public\s+"
    r"(?:(?:open|abstract|static|mut)\s+)*"
    r"(?P<kind>class|struct|enum|interface|func|type|let|var|prop|init|operator)\b"
)
TYPE_SCOPE_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"(?:(?P<visibility>public|private|protected|internal)\s+)?"
    r"(?:(?:open|abstract|static|mut|sealed)\s+)*"
    r"(?P<kind>class|struct|enum|interface)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)
INTERFACE_MEMBER_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"(?:(?:open|abstract|static|mut)\s+)*"
    r"(?P<kind>func|prop|operator)\b"
)
ENUM_CASE_RE = re.compile(r"\|\s*([A-Za-z_][A-Za-z0-9_]*)")


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def production_files(metadata: dict, root: Path = ROOT) -> list[Path]:
    files: list[Path] = []
    for source_root in metadata["source_roots"]:
        files.extend((root / source_root).glob("*.cj"))
    excluded = metadata["excluded_paths"]
    return sorted(
        path for path in files
        if not any(fnmatch.fnmatch(path.relative_to(root).as_posix(), pattern) for pattern in excluded)
    )


def declaration_name(text: str, kind: str) -> str:
    body = re.sub(r"^\s*(?:(?:public|private|protected|internal)\s+)?", "", text)
    body = re.sub(r"^(?:(?:open|abstract|static|mut)\s+)*", "", body)
    if kind == "operator":
        match = re.search(r"operator\s+func\s+([^\s(]+)", body)
        return "operator_" + (match.group(1) if match else "unknown")
    if kind == "init":
        return "init"
    match = re.match(r"(?:class|struct|enum|interface|func|type|let|var|prop)\s+([A-Za-z_][A-Za-z0-9_]*)", body)
    return match.group(1) if match else "unknown"


def line_offsets(source: str) -> list[int]:
    offsets = [0]
    for match in re.finditer("\n", source):
        offsets.append(match.end())
    return offsets


def physical_source_lines(source: str) -> list[str]:
    """Split source only at LF, matching line_offsets and lexical masking."""
    lines = source.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [line[:-1] if line.endswith("\r") else line for line in lines]


def line_brace_depths(masked: str) -> list[int]:
    depths: list[int] = []
    depth = 0
    for line in physical_source_lines(masked):
        depths.append(depth)
        depth += line.count("{") - line.count("}")
    return depths


def type_scopes(source: str) -> list[dict]:
    """Return lexical type scopes, including non-public implementation types."""
    masked = mask_comments_and_literals(source)
    lines = physical_source_lines(source)
    masked_lines = physical_source_lines(masked)
    offsets = line_offsets(source)
    candidates: list[dict] = []
    for index, masked_line in enumerate(masked_lines):
        match = TYPE_SCOPE_RE.match(masked_line)
        if not match:
            continue
        line_start = offsets[index]
        opening = masked.find("{", line_start + match.end())
        if opening < 0:
            continue
        closing = matching_brace(masked, opening)
        if closing is None:
            continue
        candidates.append({
            "line": index + 1,
            "start": line_start,
            "opening": opening,
            "closing": closing,
            "kind": match.group("kind"),
            "name": match.group("name"),
            "visibility": match.group("visibility") or "package",
            "signature_line": lines[index],
        })

    stack: list[dict] = []
    for scope in sorted(candidates, key=lambda item: item["opening"]):
        while stack and scope["opening"] > stack[-1]["closing"]:
            stack.pop()
        parent = stack[-1] if stack else None
        scope["parent"] = parent
        scope["public_contract"] = (
            scope["visibility"] == "public"
            and (parent is None or parent["public_contract"])
        )
        if parent is not None and parent["public_contract"]:
            scope["qualified"] = f"{parent['qualified']}.{scope['name']}"
            scope["root_owner"] = parent["root_owner"]
        else:
            scope["qualified"] = scope["name"]
            scope["root_owner"] = scope["name"]
        stack.append(scope)
    return candidates


def enclosing_type(scopes: list[dict], offset: int) -> dict | None:
    enclosing = [scope for scope in scopes if scope["opening"] < offset < scope["closing"]]
    return max(enclosing, key=lambda item: item["opening"]) if enclosing else None


def public_record(
    *,
    package: str,
    relative: str,
    line: int,
    level: str,
    kind: str,
    symbol: str,
    owner_symbol: str,
    qualified_symbol: str,
    signature: str,
    visibility_origin: str,
    member_kind: str | None = None,
) -> dict:
    record = {
        "package": package,
        "path": relative,
        "line": line,
        "level": level,
        "kind": kind,
        "symbol": symbol,
        "owner_symbol": owner_symbol,
        "qualified_symbol": qualified_symbol,
        "signature": signature,
        "visibility": "public",
        "visibility_origin": visibility_origin,
    }
    if member_kind is not None:
        record["member_kind"] = member_kind
    return record


def normalized_signature(lines: list[str], start: int, kind: str) -> str:
    parts = [lines[start].strip()]
    if kind not in {"func", "init", "operator"}:
        return re.sub(r"\s+", " ", parts[0])
    parens = parts[0].count("(") - parts[0].count(")")
    index = start
    while parens > 0 and index + 1 < len(lines):
        index += 1
        part = lines[index].strip()
        parts.append(part)
        parens += part.count("(") - part.count(")")
    signature = re.sub(r"\s+", " ", " ".join(parts))
    signature = re.sub(r"\s*\{.*$", "", signature).strip()
    return signature


def mask_comments_and_literals(source: str) -> str:
    """Preserve source offsets while hiding comments and quoted literals.

    The contract extractor is deliberately lexical rather than a complete
    Cangjie parser. Masking non-code text is sufficient for the repository's
    enum syntax and prevents braces, pipes, and parentheses in documentation,
    comments, or literals from becoming declarations.
    """
    out = list(source)
    index = 0
    block_depth = 0
    quote: str | None = None
    escaped = False
    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""
        if block_depth > 0:
            if char == "/" and next_char == "*":
                out[index] = out[index + 1] = " "
                block_depth += 1
                index += 2
                continue
            if char == "*" and next_char == "/":
                out[index] = out[index + 1] = " "
                block_depth -= 1
                index += 2
                continue
            if char != "\n":
                out[index] = " "
            index += 1
            continue
        if quote is not None:
            if char != "\n":
                out[index] = " "
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char == "/" and next_char == "/":
            while index < len(source) and source[index] != "\n":
                out[index] = " "
                index += 1
            continue
        if char == "/" and next_char == "*":
            out[index] = out[index + 1] = " "
            block_depth = 1
            index += 2
            continue
        if char in {'"', "'"}:
            out[index] = " "
            quote = char
            escaped = False
        index += 1
    return "".join(out)


def matching_brace(masked: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(masked)):
        if masked[index] == "{":
            depth += 1
        elif masked[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def enum_case_end(masked: str, start: int, body_end: int) -> int:
    """Return the end offset of one `| Case(...)` constructor signature."""
    match = ENUM_CASE_RE.match(masked, start)
    if not match:
        return start
    index = match.end()
    while index < body_end and masked[index].isspace() and masked[index] != "\n":
        index += 1
    if index >= body_end or masked[index] != "(":
        return match.end()
    depth = 0
    while index < body_end:
        char = masked[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return body_end


def extract_enum_constructors(
    source: str,
    relative: str,
    package: str,
    enum_records: list[dict],
) -> list[dict]:
    """Extract public enum constructors with containing-enum ownership.

    Constructors inherit the containing enum's classification. The scanner
    supports the repository's one-line constructors as well as multiline and
    nested payload types, multiple constructors on one line, and generic enum
    declarations. It does not claim to be a universal Cangjie parser.
    """
    masked = mask_comments_and_literals(source)
    line_offsets = [0]
    for match in re.finditer("\n", source):
        line_offsets.append(match.end())
    records: list[dict] = []
    for enum_record in enum_records:
        line_start = line_offsets[enum_record["line"] - 1]
        opening = masked.find("{", line_start)
        if opening < 0:
            continue
        closing = matching_brace(masked, opening)
        if closing is None:
            continue
        index = opening + 1
        curly_depth = 0
        while index < closing:
            char = masked[index]
            if char == "{":
                curly_depth += 1
            elif char == "}":
                curly_depth = max(0, curly_depth - 1)
            elif char == "|" and curly_depth == 0:
                match = ENUM_CASE_RE.match(masked, index)
                if match:
                    end = enum_case_end(masked, index, closing)
                    signature = re.sub(r"\s+", " ", masked[index + 1:end]).strip()
                    symbol = match.group(1)
                    records.append({
                        "package": package,
                        "path": relative,
                        "line": source.count("\n", 0, index) + 1,
                        "column": index - source.rfind("\n", 0, index),
                        "level": "enum_constructor",
                        "kind": "enum_constructor",
                        "symbol": symbol,
                        "owner_symbol": enum_record["symbol"],
                        "qualified_symbol": f"{enum_record['symbol']}.{symbol}",
                        "signature": signature,
                        "visibility": "public",
                        "visibility_origin": "containing_enum",
                    })
                    index = end
                    continue
            index += 1
    return records


def extract(metadata: dict, root: Path = ROOT) -> list[dict]:
    records: list[dict] = []
    for path in production_files(metadata, root):
        relative = path.relative_to(root).as_posix()
        package = relative.split("/")[1]
        source = path.read_text(encoding="utf-8")
        lines = physical_source_lines(source)
        masked = mask_comments_and_literals(source)
        masked_lines = physical_source_lines(masked)
        offsets = line_offsets(source)
        depths = line_brace_depths(masked)
        scopes = type_scopes(source)
        scopes_by_line = {scope["line"]: scope for scope in scopes}
        file_records: list[dict] = []
        for index, line in enumerate(lines):
            masked_line = masked_lines[index]
            scope = scopes_by_line.get(index + 1)
            if scope is not None:
                if not scope["public_contract"]:
                    continue
                parent = scope["parent"]
                level = "top_level" if parent is None else "member"
                file_records.append(public_record(
                    package=package,
                    relative=relative,
                    line=index + 1,
                    level=level,
                    kind=scope["kind"],
                    symbol=scope["name"],
                    owner_symbol=scope["root_owner"],
                    qualified_symbol=scope["qualified"],
                    signature=normalized_signature(lines, index, scope["kind"]),
                    visibility_origin="explicit",
                ))
                continue

            match = PUBLIC_RE.match(masked_line)
            owner = enclosing_type(scopes, offsets[index])
            if match:
                kind = match.group("kind")
                symbol = declaration_name(masked_line, kind)
                if owner is None:
                    level = "top_level"
                    owner_symbol = symbol
                    qualified = symbol
                    member_kind = None
                elif owner["public_contract"] and depths[index] == depths[owner["line"] - 1] + 1:
                    level = "member"
                    owner_symbol = owner["root_owner"]
                    qualified = f"{owner['qualified']}.{symbol}"
                    member_kind = "interface_member" if owner["kind"] == "interface" else None
                else:
                    continue
                file_records.append(public_record(
                    package=package,
                    relative=relative,
                    line=index + 1,
                    level=level,
                    kind=kind,
                    symbol=symbol,
                    owner_symbol=owner_symbol,
                    qualified_symbol=qualified,
                    signature=normalized_signature(lines, index, kind),
                    visibility_origin="explicit",
                    member_kind=member_kind,
                ))
                continue

            implicit = INTERFACE_MEMBER_RE.match(masked_line)
            if (
                implicit is None
                or owner is None
                or not owner["public_contract"]
                or owner["kind"] != "interface"
                or depths[index] != depths[owner["line"] - 1] + 1
            ):
                continue
            kind = implicit.group("kind")
            symbol = declaration_name(masked_line, kind)
            file_records.append(public_record(
                package=package,
                relative=relative,
                line=index + 1,
                level="member",
                kind=kind,
                symbol=symbol,
                owner_symbol=owner["root_owner"],
                qualified_symbol=f"{owner['qualified']}.{symbol}",
                signature=normalized_signature(lines, index, kind),
                visibility_origin="interface",
                member_kind="interface_member",
            ))
        enum_records = [
            record for record in file_records
            if record["level"] == "top_level" and record["kind"] == "enum"
        ]
        file_records.extend(extract_enum_constructors(source, relative, package, enum_records))
        records.extend(file_records)
    return records


def excluded_test_declaration_count(metadata: dict, root: Path = ROOT) -> int:
    all_source_metadata = dict(metadata)
    all_source_metadata["excluded_paths"] = []
    return sum(
        1 for record in extract(all_source_metadata, root)
        if any(fnmatch.fnmatch(record["path"], pattern) for pattern in metadata["excluded_paths"])
    )


def matching_rule(record: dict, metadata: dict) -> dict | None:
    matches = []
    for order, rule in enumerate(metadata["rules"]):
        match = rule["match"]
        if "package" in match and match["package"] != record["package"]:
            continue
        if "path" in match and not fnmatch.fnmatch(record["path"], match["path"]):
            continue
        if "symbols" in match and record["owner_symbol"] not in match["symbols"]:
            continue
        if "qualified_symbols" in match and record["qualified_symbol"] not in match["qualified_symbols"]:
            continue
        specificity = (
            (8 if "qualified_symbols" in match else 0)
            + (4 if "symbols" in match else 0)
            + (2 if "path" in match else 0)
            + (1 if "package" in match else 0)
        )
        matches.append((specificity, order, rule))
    if not matches:
        return None
    return max(matches, key=lambda item: (item[0], item[1]))[2]


def classify(records: list[dict], metadata: dict) -> list[dict]:
    classified = []
    for record in records:
        rule = matching_rule(record, metadata)
        entry = dict(record)
        if rule is None:
            entry.update({"stability": "UNCLASSIFIED", "classification_rule": None})
        else:
            entry.update({
                "stability": rule["stability"],
                "classification_rule": rule["id"],
                "subsystem": rule["subsystem"],
                "architecture_owner": rule["owner"],
                "disposition": rule.get("disposition", "keep"),
            })
        classified.append(entry)
    return classified


def contract_line(record: dict, with_line: bool = False) -> str:
    prefix = f"{record['path']}:{record['line']}:" if with_line else f"{record['path']}:"
    return prefix + record["signature"]


def classified_contract_line(record: dict) -> str:
    return f"{record['package']}|{record['qualified_symbol']}|{record['kind']}|{record['signature']}"


def rendered_outputs(records: list[dict], metadata: dict) -> dict[Path, str]:
    sorted_records = sorted(
        records,
        key=lambda r: (
            r["path"], r["line"], r.get("column", 0),
            r["qualified_symbol"], r["signature"],
        ),
    )
    counts = Counter(record["stability"] for record in sorted_records)
    top_counts = Counter(record["stability"] for record in sorted_records if record["level"] == "top_level")
    enum_counts = Counter(
        record["stability"] for record in sorted_records
        if record["level"] == "top_level" and record["kind"] == "enum"
    )
    enum_constructor_counts = Counter(
        record["stability"] for record in sorted_records
        if record["level"] == "enum_constructor"
    )
    inventory = {
        "format_version": 1,
        "contract_kind": "cangjie-source-level-public-api",
        "generated": True,
        "classification_source": "architecture/api-classification.json",
        "contract_coverage": {
            "public_declarations": True,
            "public_enum_constructors": "complete_for_repository_syntax",
            "enum_constructor_stability": "inherits_containing_enum",
        },
        "limitations": [
            "This is a source declaration contract, not an ABI compatibility claim.",
            "Enum constructors are inventoried lexically for repository syntax; this is not a universal Cangjie parser.",
            "Nested generic payload dependencies are resolved by exact top-level symbol names within the declaring package.",
        ],
        "counts": {
            "production_public_declarations": len(sorted_records),
            "production_public_top_level": sum(top_counts.values()),
            "test_source_public_declarations_excluded": excluded_test_declaration_count(metadata),
            "by_stability": dict(sorted(counts.items())),
            "top_level_by_stability": dict(sorted(top_counts.items())),
            "enum_top_level_by_stability": dict(sorted(enum_counts.items())),
            "enum_constructors_by_stability": dict(sorted(enum_constructor_counts.items())),
        },
        "symbols": sorted_records,
    }
    stable = [record for record in sorted_records if record["stability"] == "STABLE"]
    experimental = [record for record in sorted_records if record["stability"] == "EXPERIMENTAL"]
    return {
        INVENTORY: json.dumps(inventory, indent=2, ensure_ascii=False) + "\n",
        LEGACY_CONTRACT: "\n".join(contract_line(record) for record in sorted_records) + "\n",
        LEGACY_INDEX: "\n".join(contract_line(record, with_line=True) for record in sorted_records) + "\n",
        STABLE_CONTRACT: "\n".join(classified_contract_line(record) for record in stable) + "\n",
        EXPERIMENTAL_CONTRACT: "\n".join(classified_contract_line(record) for record in experimental) + "\n",
    }


def validate_metadata(records: list[dict], metadata: dict) -> list[str]:
    errors: list[str] = []
    allowed = {"STABLE", "EXPERIMENTAL", "INTERNAL", "TEST_ONLY"}
    rule_ids = [rule["id"] for rule in metadata["rules"]]
    if len(rule_ids) != len(set(rule_ids)):
        errors.append("classification rule ids must be unique")
    for rule in metadata["rules"]:
        if rule["stability"] not in allowed:
            errors.append(f"{rule['id']}: invalid stability {rule['stability']}")
        for required in ("subsystem", "owner", "reason", "consumer_evidence"):
            if not rule.get(required):
                errors.append(f"{rule['id']}: missing {required}")
        if rule["stability"] == "EXPERIMENTAL":
            for required in ("promotion_condition", "sunset_condition"):
                if not rule.get(required):
                    errors.append(f"{rule['id']}: experimental rule missing {required}")
    unclassified = [record for record in records if record["stability"] == "UNCLASSIFIED"]
    for record in unclassified:
        errors.append(f"unclassified: {record['path']}:{record['line']} {record['qualified_symbol']}")
    top_level = {(record["package"], record["owner_symbol"]) for record in records if record["level"] == "top_level"}
    enums = {
        (record["package"], record["symbol"]): record
        for record in records
        if record["level"] == "top_level" and record["kind"] == "enum"
    }
    for record in records:
        if record["level"] != "enum_constructor":
            continue
        owner = enums.get((record["package"], record["owner_symbol"]))
        if owner is None:
            errors.append(f"enum constructor lacks public enum owner: {record['qualified_symbol']}")
        elif record["stability"] != owner["stability"]:
            errors.append(
                f"enum constructor stability must inherit owner: {record['qualified_symbol']} "
                f"{record['stability']} != {owner['stability']}"
            )
    for rule in metadata["rules"]:
        for symbol in rule["match"].get("symbols", []):
            package = rule["match"].get("package")
            if package and (package, symbol) not in top_level:
                errors.append(f"{rule['id']}: classified symbol no longer exists: {package}.{symbol}")
    return errors


def generate(check: bool) -> int:
    metadata = load_json(CLASSIFICATION)
    records = classify(extract(metadata), metadata)
    errors = validate_metadata(records, metadata)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    outputs = rendered_outputs(records, metadata)
    stale = []
    for path, content in outputs.items():
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            stale.append(path)
            if not check:
                path.write_text(content, encoding="utf-8")
    if check and stale:
        for path in stale:
            print(f"stale generated API output: {path.relative_to(ROOT)}", file=sys.stderr)
        return 1
    action = "checked" if check else "generated"
    print(f"{action} classified API contract: {len(records)} production declarations, 0 unclassified")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return generate(args.check)


if __name__ == "__main__":
    raise SystemExit(main())
