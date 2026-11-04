#!/usr/bin/env python3
"""Generate per-package cjdoc sites from the production source inventory."""

from __future__ import annotations

import argparse
import html
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from api_contract import CLASSIFICATION, ROOT, load_json, production_files

PORTAL_MARKER = ".termcanvas-cjdoc-output.json"


def documentation_sites(members: list[Path], sources: list[Path]) -> list[tuple[str, Path, list[Path]]]:
    sites = []
    for member in members:
        files = [source for source in sources if source.parent == ROOT / member / "src"]
        if member.name != "core":
            sites.append((member.name, member, files))
            continue
        # The expanded core exceeds cjdoc 0.7.2's 32 MiB Doc IR limit.
        # Partition whole source files without changing their declarations.
        shards: list[list[Path]] = [[], []]
        sizes = [0, 0]
        for source in sorted(files, key=lambda path: (-path.stat().st_size, path.name)):
            index = 0 if sizes[0] <= sizes[1] else 1
            shards[index].append(source)
            sizes[index] += source.stat().st_size
        for index, shard in enumerate(shards, 1):
            sites.append((f"core-{index}", member, sorted(shard)))
    return sites


def portal(names: list[str], coverages: dict[str, dict]) -> str:
    links = []
    for name in names:
        counts = coverages[name]["symbols"]
        links.append(
            f'<li><a href="packages/{html.escape(name)}/html/index.html">{html.escape(name)}</a>'
            f' <small>{counts["documented"]}/{counts["total"]} 条声明有说明</small></li>'
        )
    return (
        '<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Termcanvas API 文档</title>'
        '<style>body{font:1.1rem/1.65 system-ui,sans-serif;max-width:48rem;margin:3rem auto;'
        'padding:0 1.5rem;color:#182334}a{color:#1456a0}li{margin:.6rem 0}'
        'small{color:#566273;margin-left:1rem}</style>'
        f'<h1>Termcanvas API 文档</h1><p>cjdoc 0.7.2 的 {len(names)} 个独立源码站点。'
        'core 分为两个源码分片，其余包各有一个站点；跨站点类型以签名呈现。</p><ul>'
        + "".join(links) + '</ul></html>\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=ROOT / "target/doc",
        help="portal directory (relative paths use the caller's working directory)",
    )
    args = parser.parse_args()
    version = subprocess.run(["cjdoc", "--version"], capture_output=True, text=True)
    if version.returncode != 0 or version.stdout.strip() != "cjdoc 0.7.2":
        parser.error("this generator requires cjdoc 0.7.2 on PATH")
    output = args.output.resolve()
    metadata = load_json(CLASSIFICATION)
    members = sorted({Path(*Path(source_root).parts[:2]) for source_root in metadata["source_roots"]})
    sources = production_files(metadata)
    sites = documentation_sites(members, sources)
    names = [name for name, _, _ in sites]
    marker = output / PORTAL_MARKER
    if output.exists():
        owned = load_json(marker) if marker.is_file() else None
        if not output.is_dir() or not isinstance(owned, dict) or owned.get("version") != 1:
            parser.error(f"output is not a managed Termcanvas cjdoc portal: {output}")
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.mkdir()
        marker.write_text(json.dumps({"version": 1, "packages": names}) + "\n", encoding="utf-8")

    environment = os.environ.copy()
    # The runtime's 256 MiB default heap is insufficient for the core AST.
    environment.setdefault("cjHeapSize", "1GB")
    manifest = {
        "version": 1,
        "packages": names,
        "sources": {
            name: [source.relative_to(ROOT).as_posix() for source in files]
            for name, _, files in sites
        },
    }
    coverages: dict[str, dict] = {}
    with tempfile.TemporaryDirectory(prefix="cjdoc-") as temporary:
        for name, member, files in sites:
            stage = Path(temporary) / name
            stage.mkdir()
            shutil.copy2(ROOT / member / "cjpm.toml", stage / "cjpm.toml")
            for source in files:
                destination = stage / "src" / source.name
                destination.parent.mkdir(exist_ok=True)
                shutil.copy2(source, destination)
            destination = output / "packages" / name
            destination.parent.mkdir(exist_ok=True)
            status = subprocess.run([
                "cjdoc", "generate", "--project", str(stage),
                "--format", "json", "--format", "html", "--format", "markdown", "--format", "coverage",
                "--output", str(destination),
                "--audience", "external", "--lint-profile", "standard", "--jobs", "1",
                "--cfg", "os=Linux", "--cfg", "arch=x86_64", "--no-cache",
                "--locale", "zh-CN", "--markdown-layout", "site",
            ], env=environment).returncode
            if status != 0:
                return status
            coverages[name] = load_json(destination / "coverage" / "coverage.json")

    (output / "index.html").write_text(portal(names, coverages), encoding="utf-8")
    marker.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"generated {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
