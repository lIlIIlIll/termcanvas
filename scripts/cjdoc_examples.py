"""Validate shared documentation examples and link them from cjdoc pages."""
from __future__ import annotations

import html
import json
import os
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from api_contract import ROOT

MANIFEST = ROOT / "docs/api-examples/manifest.json"
IDENTIFIER = re.compile(r"^[a-z][a-z0-9-]*$")
TARGETS = {"linux", "macos", "windows"}
KINDS = {"class": "class", "struct": "struct", "enum": "enum", "interface": "interface",
         "func": "function", "operator": "function", "init": "constructor",
         "let": "variable", "var": "variable", "prop": "property",
         "type": "typeAlias", "enum_constructor": "enumCase"}


def declaration_key(item: dict) -> tuple[str, str, str, str]:
    return item["package"], item["path"], item["symbol"], item["signature"]


def load_examples(inventory: dict) -> tuple[list[dict], list[Path]]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if data.get("format_version") != 1 or not isinstance(data.get("scenarios"), list):
        raise ValueError("invalid documentation example manifest")
    eligible: dict[tuple[str, str, str, str], list[dict]] = {}
    for item in inventory["symbols"]:
        if item["stability"] in ("STABLE", "EXPERIMENTAL"):
            key = (item["package"], item["path"], item["qualified_symbol"], item["signature"])
            eligible.setdefault(key, []).append(item)
    packages = {Path(item["path"]).parts[1] for item in inventory["symbols"]
                if len(Path(item["path"]).parts) >= 3 and Path(item["path"]).parts[0] == "packages"}
    seen_ids: set[str] = set()
    seen_bindings: set[tuple[str, str, str, str]] = set()
    sources = [MANIFEST]
    for scenario in data["scenarios"]:
        if not isinstance(scenario, dict):
            raise ValueError("invalid documentation example")
        name = scenario["id"]
        if not isinstance(name, str) or not IDENTIFIER.fullmatch(name) or name in seen_ids:
            raise ValueError(f"invalid or duplicate example id: {name}")
        seen_ids.add(name)
        if not isinstance(scenario.get("source"), str):
            raise ValueError(f"invalid source for example {name}")
        source = (ROOT / scenario["source"]).resolve()
        directory = (ROOT / "docs/api-examples").resolve()
        if not source.is_relative_to(directory) or not source.is_file() or source.suffix != ".cj":
            raise ValueError(f"invalid source for example {name}")
        sources.append(source)
        targets = scenario["platforms"]
        if (not isinstance(targets, list) or not targets or not all(isinstance(target, str) for target in targets)
            or len(set(targets)) != len(targets) or not set(targets) <= TARGETS):
            raise ValueError(f"invalid target platforms for example {name}")
        dependencies = scenario["dependencies"]
        if (not isinstance(dependencies, list) or not all(isinstance(dep, str) for dep in dependencies)
            or len(set(dependencies)) != len(dependencies) or not set(dependencies) <= packages):
            raise ValueError(f"invalid dependencies for example {name}")
        if not isinstance(scenario["declarations"], list) or not scenario["declarations"]:
            raise ValueError(f"missing declarations for example {name}")
        for binding in scenario["declarations"]:
            if not isinstance(binding, dict):
                raise ValueError(f"invalid declaration binding for example {name}")
            key = declaration_key(binding)
            if key not in eligible or key in seen_bindings:
                raise ValueError(f"unknown or duplicate application API binding: {key}")
            seen_bindings.add(key)
            binding["_inventory"] = eligible[key]
    return data["scenarios"], sources


def link_examples(built: Path, sites: list[dict], scenarios: list[dict]) -> None:
    examples = built / "examples"
    examples.mkdir(exist_ok=True)
    for scenario in scenarios:
        source = ROOT / scenario["source"]
        code = html.escape(source.read_text(encoding="utf-8"))
        name = scenario["id"]
        (examples / f"{name}.html").write_text(
            '<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{html.escape(name)} · Termcanvas 示例</title>'
            '<style>body{font:1rem/1.6 system-ui,sans-serif;max-width:70rem;margin:2rem auto;padding:0 1rem}'
            'pre{overflow:auto;background:#f3f4f6;padding:1rem}</style>'
            f'<p><a href="../index.html">API 参考</a></p><h1>{html.escape(name)}</h1>'
            '<p>此示例用于独立应用；使用它之前请核对目标平台的实际验证结果。</p>'
            f'<pre><code>{code}</code></pre></html>\n', encoding="utf-8")
    linked = {declaration_key(binding): 0 for scenario in scenarios for binding in scenario["declarations"]}
    for site in sites:
        package, target = site["package"], site["platform"]
        site_root = built / "packages" / package / target / "html"
        entries = json.loads((site_root / "symbol-index.json").read_text(encoding="utf-8"))["entries"]
        by_name: dict[tuple[str, str, str], list[dict]] = {}
        for entry in entries:
            source = entry.get("source") or {}
            by_name.setdefault((entry["qualifiedName"], source.get("path", ""), entry["kind"]), []).append(entry)
        for scenario in scenarios:
            if target not in scenario["platforms"]:
                continue
            for binding in scenario["declarations"]:
                for item in binding["_inventory"]:
                    path = Path(item["path"])
                    if len(path.parts) < 4 or path.parts[1] != package:
                        continue
                    qualified = item["package"] + "." + item["qualified_symbol"].replace(".operator_", ".")
                    candidates = by_name.get((qualified, Path(*path.parts[2:]).as_posix(), KINDS[item["kind"]]), [])
                    matches = [entry for entry in candidates if entry["source"]["start"]["line"] <= item["line"] <= entry["source"]["end"]["line"]]
                    if len(matches) > 1:
                        raise ValueError(f"ambiguous example link for {qualified}")
                    if not matches:
                        continue
                    href = urlsplit(matches[0]["href"])
                    page = (site_root / unquote(href.path)).resolve()
                    if href.scheme or href.netloc or not page.is_relative_to(site_root.resolve()) or not page.is_file():
                        raise ValueError(f"invalid generated page for {qualified}")
                    example = examples / f'{scenario["id"]}.html'
                    relative = Path(os.path.relpath(example, page.parent)).as_posix()
                    marker = f'termcanvas-example-{scenario["id"]}'
                    text = page.read_text(encoding="utf-8")
                    if marker not in text:
                        if text.count("</main>") != 1:
                            raise ValueError(f"unexpected page layout for {qualified}")
                        section = (f'<section id="{marker}"><h2>共享示例</h2>'
                                   f'<p><a href="{html.escape(relative, quote=True)}">'
                                   f'{html.escape(scenario["id"])}</a></p></section>')
                        page.write_text(text.replace("</main>", section + "</main>", 1), encoding="utf-8")
                    linked[declaration_key(binding)] += 1
    selected_sites = {(site["package"], site["platform"]) for site in sites}
    for scenario in scenarios:
        for binding in scenario["declarations"]:
            item = binding["_inventory"][0]
            package = Path(item["path"]).parts[1]
            applicable = any((package, target) in selected_sites for target in scenario["platforms"])
            if applicable and not linked[declaration_key(binding)]:
                raise ValueError(f'example binding has no generated page: {item["qualified_symbol"]}')
