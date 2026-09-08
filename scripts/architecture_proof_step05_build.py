#!/usr/bin/env python3
"""Build a provenance-locked real omp-cj consumer for Step 0.5.

The consumer is copied to an isolated /tmp tree with no target directory. Its
`../../termcanvas` sibling is a symlink to the live workspace, so cjpm must compile
the exact instrumented core while leaving both source workspaces untouched.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from typing import Any


EXCLUDED_DIRS = {
    ".git", "target", "perf_results", ".runtime-archives", ".workshops",
    "dist", "__pycache__", "results",
}


def run(command: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, check=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def aggregate_source_hash(root: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    count = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or any(part in EXCLUDED_DIRS for part in path.relative_to(root).parts):
            continue
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256(path)))
        count += 1
    return digest.hexdigest(), count


def repo_state(root: Path) -> dict[str, Any]:
    if not (root / ".git").exists():
        aggregate, file_count = aggregate_source_hash(root)
        return {
            "root": str(root.resolve()),
            "head": "snapshot-without-git-metadata",
            "dirty_files": [],
            "source_aggregate_sha256": aggregate,
            "source_file_count": file_count,
            "snapshot_source": True,
        }
    status_output = run(["but", "status", "--json"], root).stdout
    json_start = status_output.find("{")
    if json_start < 0:
        raise ValueError("GitButler status did not contain a JSON object")
    status = json.loads(status_output[json_start:])
    dirty: list[dict[str, Any]] = []
    for change in status.get("uncommittedChanges", []):
        path = root / change["filePath"]
        dirty.append({
            "path": change["filePath"],
            "change_type": change["changeType"],
            "sha256": sha256(path) if path.is_file() else None,
        })
    aggregate, file_count = aggregate_source_hash(root)
    return {
        "root": str(root.resolve()),
        "head": run(["git", "rev-parse", "HEAD"], root).stdout.strip(),
        "dirty_files": dirty,
        "source_aggregate_sha256": aggregate,
        "source_file_count": file_count,
    }


def ignored(_: str, names: list[str]) -> set[str]:
    return {name for name in names if name in EXCLUDED_DIRS}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--termcanvas-root", type=Path, required=True)
    parser.add_argument("--consumer-root", type=Path, required=True)
    parser.add_argument("--sdk-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    termcanvas = args.termcanvas_root.resolve()
    consumer = args.consumer_root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    cj_state = repo_state(termcanvas)
    consumer_state = repo_state(consumer)
    build_root = Path(tempfile.mkdtemp(prefix="termcanvas-step05-build-", dir="/tmp"))
    snapshot_consumer = build_root / "learn_agent_cj"
    shutil.copytree(consumer, snapshot_consumer, ignore=ignored, symlinks=True)
    snapshot_termcanvas = build_root / "termcanvas"
    snapshot_termcanvas.symlink_to(termcanvas, target_is_directory=True)

    core_dependency = (snapshot_consumer / "agent_tui" / "../../termcanvas/packages/core").resolve()
    markdown_dependency = (snapshot_consumer / "agent_tui" / "../../termcanvas/packages/markdown").resolve()
    expected_core = (termcanvas / "packages/core").resolve()
    if core_dependency != expected_core:
        raise SystemExit(f"resolved core dependency {core_dependency} != {expected_core}")
    if (snapshot_consumer / "target").exists():
        raise SystemExit("isolated consumer unexpectedly contains a pre-existing target directory")

    environment = os.environ.copy()
    environment.update({"DISABLE_ZOXIDE": "1", "OMP_CJ_SDK_ROOT": str(args.sdk_root.resolve())})
    started_ns = time.time_ns()
    build = subprocess.run(
        [str(snapshot_consumer / "scripts/pinned_cangjie"), "cjpm", "build", "-m", "agent_app"],
        cwd=snapshot_consumer,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    completed_ns = time.time_ns()
    (output / "build.log").write_text(build.stdout, encoding="utf-8")
    if build.returncode != 0:
        raise SystemExit(f"isolated consumer build failed; see {output / 'build.log'}")

    built_binary = snapshot_consumer / "target/release/bin/agent_app"
    if not built_binary.is_file():
        raise SystemExit(f"fresh build did not produce {built_binary}")
    binary_dir = output / "bin"
    binary_dir.mkdir(exist_ok=True)
    preserved_binary = binary_dir / "agent_app"
    shutil.copy2(built_binary, preserved_binary)

    compiler = run([str(snapshot_consumer / "scripts/pinned_cangjie"), "cjc", "-v"], snapshot_consumer, environment)
    provenance = {
        "schema_version": 1,
        "build_order": 1,
        "build_started_unix_ns": started_ns,
        "build_completed_unix_ns": completed_ns,
        "build_mode": "release",
        "isolated_target_preexisted": False,
        "build_root": str(build_root),
        "consumer_snapshot": str(snapshot_consumer),
        "termcanvas": cj_state,
        "consumer": consumer_state,
        "declared_dependency": {
            "manifest": str((consumer / "agent_tui/cjpm.toml").resolve()),
            "core": "../../termcanvas/packages/core",
            "markdown": "../../termcanvas/packages/markdown",
        },
        "resolved_dependency": {
            "core": str(core_dependency),
            "markdown": str(markdown_dependency),
            "uses_live_termcanvas_workspace": core_dependency == expected_core,
        },
        "sdk_root": str(args.sdk_root.resolve()),
        "compiler_version": compiler.stdout.strip(),
        "binary": {
            "path": str(preserved_binary),
            "fresh_build_path": str(built_binary),
            "sha256": sha256(preserved_binary),
            "size_bytes": preserved_binary.stat().st_size,
            "mtime_ns": preserved_binary.stat().st_mtime_ns,
        },
        "build_log": str(output / "build.log"),
    }
    (output / "provenance.json").write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(provenance["binary"], sort_keys=True))
    print(f"provenance={output / 'provenance.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
