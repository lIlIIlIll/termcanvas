#!/usr/bin/env python3
"""Report, but do not certify, application-API documentation in a cjdoc portal."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import sys

from api_contract import CLASSIFICATION, ROOT, load_json
from generate_cjdoc import MARKER, sha256
from cjdoc_examples import declaration_key, load_examples

CHINESE = re.compile(r"[\u3400-\u9fff]")
KINDS = {"class": "class", "struct": "struct", "enum": "enum", "interface": "interface",
         "func": "function", "operator": "function", "init": "constructor",
         "let": "variable", "var": "variable", "prop": "property",
         "type": "typeAlias", "enum_constructor": "enumCase"}


def return_documented(declaration: dict) -> bool:
    if declaration.get("kind") != "function":
        return True
    result = declaration.get("returnType")
    if not isinstance(result, dict):
        return False
    if (result.get("spelling") or "").replace(" ", "") == "Unit":
        return True
    doc = declaration.get("documentation") or {}
    return any(tag.get("name") == "return" and CHINESE.search(tag.get("description") or "")
               for tag in doc.get("tags", []))


def audit(portal: Path) -> dict:
    marker = json.loads((portal / MARKER).read_text(encoding="utf-8"))
    if marker.get("format_version") != 1:
        raise ValueError("not a supported Termcanvas cjdoc portal")
    for name, digest in marker["sources"].items():
        source = (ROOT / name).resolve()
        if not source.is_relative_to(ROOT.resolve()) or not source.is_file() or sha256(source) != digest:
            raise ValueError(f"portal does not match current source: {name}")
    inventory = json.loads((portal / "api-inventory.json").read_text(encoding="utf-8"))
    sites = marker["sites"]
    metadata = load_json(CLASSIFICATION)
    expected_packages = {Path(path).parts[1] for path in metadata["source_roots"]}
    expected_targets = {"linux", "macos", "windows"}
    configured_sites = {(site["package"], site["platform"]) for site in sites}
    if any(package not in expected_packages or target not in expected_targets for package, target in configured_sites):
        raise ValueError("portal has unknown package or platform")
    if not marker.get("partial") and configured_sites != {(package, target) for package in expected_packages for target in expected_targets}:
        raise ValueError("portal is marked complete but omits a package or platform")
    scenarios, _ = load_examples(inventory)
    bindings = {declaration_key(binding): scenario for scenario in scenarios for binding in scenario["declarations"]}
    symbol_pages: dict[tuple[str, str, str], Path] = {}
    index: dict[tuple[str, str, str], list[tuple[str, dict]]] = defaultdict(list)
    seen = set()
    for site in sites:
        package, target = site["package"], site["platform"]
        if (package, target) in seen:
            raise ValueError(f"duplicate generated site: {package}/{target}")
        seen.add((package, target))
        doc = json.loads((portal / "packages" / package / target / "docs.json").read_text(encoding="utf-8"))
        if doc.get("status") != "complete" or any(x.get("severity") == "error" for x in doc["diagnostics"]):
            raise ValueError(f"incomplete generated site: {package}/{target}")
        site_root = portal / "packages" / package / target / "html"
        symbol_index = site_root / "symbol-index.json"
        if symbol_index.is_file():
            for entry in json.loads(symbol_index.read_text(encoding="utf-8"))["entries"]:
                page = (site_root / entry["href"].split("#", 1)[0]).resolve()
                if not page.is_relative_to(site_root.resolve()):
                    raise ValueError("generated symbol page leaves site")
                symbol_pages[(package, target, entry["id"])] = page
        for declaration in doc["declarations"]:
            source = declaration.get("source") or {}
            if source.get("path"):
                key = (package, source["path"], declaration["qualifiedName"])
                index[key].append((target, declaration))
    packages = {site["package"] for site in sites}
    counters = Counter()
    missing = []
    for item in inventory["symbols"]:
        if item["stability"] not in ("STABLE", "EXPERIMENTAL"):
            continue
        path = Path(item["path"])
        if len(path.parts) < 4 or path.parts[1] not in packages:
            continue
        package = path.parts[1]
        source_path = Path(*path.parts[2:]).as_posix()
        name = item["qualified_symbol"].replace(".operator_", ".")
        qualified = item["package"] + "." + name
        expected_kind = KINDS.get(item["kind"])
        if expected_kind is None:
            raise ValueError(f"unsupported inventory kind: {item['kind']}")
        candidates = []
        for target, declaration in index.get((package, source_path, qualified), []):
            source = declaration["source"]
            if (declaration["kind"] == expected_kind and
                source["start"]["line"] <= item["line"] <= source["end"]["line"]):
                candidates.append((target, declaration))
        counters["application_declarations"] += 1
        if not candidates:
            counters["not_found"] += 1
            missing.append({"symbol": qualified, "path": item["path"], "line": item["line"], "reason": "not found in generated sites"})
            continue
        by_target = Counter(target for target, _ in candidates)
        if any(count > 1 for count in by_target.values()):
            counters["ambiguous"] += 1
            missing.append({"symbol": qualified, "path": item["path"], "line": item["line"], "reason": "ambiguous declaration mapping"})
            continue
        counters["mapped"] += 1
        docs = [declaration.get("documentation") or {} for _, declaration in candidates]
        if all(all(CHINESE.search(parameter.get("documentation") or "") for parameter in declaration.get("parameters", [])) for _, declaration in candidates):
            counters["parameters_documented"] += 1
        else:
            missing.append({"symbol": qualified, "path": item["path"], "line": item["line"], "reason": "missing parameter documentation"})
        if all(return_documented(declaration) for _, declaration in candidates):
            counters["returns_documented"] += 1
        else:
            missing.append({"symbol": qualified, "path": item["path"], "line": item["line"], "reason": "missing or unknown return documentation"})
        if all(CHINESE.search(doc.get("summary") or "") for doc in docs):
            counters["chinese_summary"] += 1
        else:
            missing.append({"symbol": qualified, "path": item["path"], "line": item["line"], "reason": "missing Chinese summary"})
        direct = all(any(tag.get("name") == "example" for tag in doc.get("tags", [])) for doc in docs)
        counters["direct_example_tag" if direct else "no_direct_example_tag"] += 1
        binding = (item["package"], item["path"], item["qualified_symbol"], item["signature"])
        scenario = bindings.get(binding)
        if scenario is not None:
            linked = True
            for target, declaration in candidates:
                page = symbol_pages.get((package, target, declaration["id"]))
                if (target not in scenario["platforms"] or page is None or not page.is_file() or
                    f'termcanvas-example-{scenario["id"]}' not in page.read_text(encoding="utf-8")):
                    linked = False
                    break
            if linked:
                counters["shared_example_linked"] += 1
            else:
                counters["shared_example_link_missing"] += 1
    return {"scope_partial": bool(marker.get("partial")), "counts": dict(counters),
            "example_execution_verified": False,
            "note": "Example tags and shared links are presence counts only; this report does not execute examples or certify coverage.",
            "first_missing": missing[:30]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("portal", type=Path)
    args = parser.parse_args()
    try:
        report = audit(args.portal)
    except (OSError, KeyError, ValueError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
