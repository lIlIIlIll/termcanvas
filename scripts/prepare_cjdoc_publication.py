#!/usr/bin/env python3
"""Prepare a verified Pages tree and expose its offline archive and evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

from check_cjdoc_completion import check
from generate_cjdoc import MARKER, ROOT, sha256


def verify_commit(revision: str, sources: dict[str, str]) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("source revision must be a full lowercase commit SHA")
    actual = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    if actual != revision:
        raise ValueError("source revision does not match checkout HEAD")
    for name, expected in sources.items():
        result = subprocess.run(["git", "show", f"{revision}:{name}"], cwd=ROOT, capture_output=True, check=False)
        if result.returncode or hashlib.sha256(result.stdout).hexdigest() != expected:
            raise ValueError(f"committed source differs from evidence: {name}")


def verify_archive(portal: Path, archive: Path) -> None:
    files = {path.relative_to(portal).as_posix(): path for path in portal.rglob("*") if path.is_file()}
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        if len(names) != len(set(names)) or set(names) != set(files):
            raise ValueError("offline archive does not contain the exact portal files")
        for name in names:
            digest = hashlib.sha256()
            with package.open(name) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            if digest.hexdigest() != sha256(files[name]):
                raise ValueError(f"offline archive differs from portal: {name}")


def prepare(portal: Path, archive: Path, attestation: Path, reports: list[Path], revision: str) -> None:
    portal = portal.resolve()
    result = check(portal, reports)
    claimed = json.loads(attestation.read_text(encoding="utf-8"))
    if result.get("status") != "passed" or claimed != result:
        raise ValueError("documentation completion evidence is incomplete or mismatched")
    sources = json.loads((portal / MARKER).read_text(encoding="utf-8"))["sources"].copy()
    by_target = {}
    for path in reports:
        report = json.loads(path.read_text(encoding="utf-8"))
        for name, digest in report["sources"].items():
            if name in sources and sources[name] != digest:
                raise ValueError(f"conflicting source identity: {name}")
            sources[name] = digest
        by_target[report["platform"]] = path
    verify_commit(revision, sources)
    verify_archive(portal, archive)
    downloads, evidence = portal / "downloads", portal / "evidence"
    if downloads.exists() or evidence.exists() or (portal / "publication-manifest.json").exists():
        raise ValueError("portal already contains publication output")
    index = portal / "index.html"
    text = index.read_text(encoding="utf-8")
    if text.count("<ul>") != 1:
        raise ValueError("unexpected portal index layout")
    downloads.mkdir()
    evidence.mkdir()
    offline = downloads / "termcanvas-api-reference.zip"
    shutil.copyfile(archive, offline)
    if sha256(offline) != sha256(archive):
        raise ValueError("published archive copy does not match validated archive")
    (downloads / "termcanvas-api-reference.zip.sha256").write_text(
        f'{sha256(offline)}  termcanvas-api-reference.zip\n', encoding="utf-8")
    shutil.copyfile(attestation, evidence / "completion.json")
    for target, path in by_target.items():
        shutil.copyfile(path, evidence / f"{target}.json")
    links = ('<p><a href="downloads/termcanvas-api-reference.zip">下载离线文档</a> · '
             '<a href="evidence/completion.json">查看验收记录</a></p>')
    index.write_text(text.replace("<ul>", links + "<ul>", 1), encoding="utf-8")
    files = {path.relative_to(portal).as_posix(): sha256(path) for path in sorted(portal.rglob("*")) if path.is_file()}
    (portal / "publication-manifest.json").write_text(json.dumps({"format_version": 1,
        "source_revision": revision, "files": files}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("portal", type=Path)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--attestation", type=Path, required=True)
    parser.add_argument("--report", action="append", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()
    try:
        prepare(args.portal, args.archive, args.attestation, args.report, args.revision)
    except (OSError, KeyError, ValueError, TypeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print("prepared verified Pages publication")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
