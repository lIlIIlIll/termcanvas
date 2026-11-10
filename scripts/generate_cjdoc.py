#!/usr/bin/env python3
"""Generate a classified, offline-browsable cjdoc portal from production packages."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

from api_contract import CLASSIFICATION, ROOT, load_json, production_files
from native_sdk import sdk_environment, verify_sdk
from normalize_cjdoc_parameters import normalize as normalize_anonymous_parameters
from cjdoc_examples import link_examples, load_examples

VERSION = "0.7.7"
SOURCE_REVISION = "8cc8f71a296b1c6321e575b56fadbd0c379e242a"
BINARY_SHA256 = {
    ("Linux", "x86_64"): "9c218e606d916a7411e70d7dc70a50ff7eeb704aa72a6fc45a284f01ae8ae386",
    ("Darwin", "arm64"): "182004e95efbae3ccd58ac0e68c274693d7e864c779c3b9adee6418e84936688",
    ("Windows", "amd64"): "141445a081a47d4de82b845b0ea8a38c798048c5c726682a714d6583b73514cc",
}
PLATFORMS = {"linux": ("Linux", "x86_64"), "macos": ("macOS", "aarch64"), "windows": ("Windows", "x86_64")}
MARKER = ".termcanvas-cjdoc-output.json"


class GenerationError(Exception):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def qualified_cjdoc(command: str, environment: dict[str, str]) -> Path:
    resolved = shutil.which(command)
    if resolved is None:
        raise GenerationError(f"cjdoc executable not found: {command}")
    executable = Path(resolved).resolve()
    key = (platform.system(), platform.machine().lower())
    expected = BINARY_SHA256.get(key)
    if expected is None:
        raise GenerationError(f"no qualified cjdoc release binary for {key}")
    if sha256(executable) != expected:
        raise GenerationError("cjdoc binary does not match the qualified 0.7.7 release checksum")
    result = subprocess.run([str(executable), "--version"], env=environment, capture_output=True, text=True, check=False, timeout=30)
    if result.returncode != 0 or result.stdout.strip() != f"cjdoc {VERSION}":
        raise GenerationError("qualified cjdoc could not run with the current Cangjie runtime")
    return executable


def source_snapshot(files: list[Path]) -> dict[str, str]:
    return {path.relative_to(ROOT).as_posix(): sha256(path) for path in sorted(files)}


def portal(sites: list[dict], partial: bool) -> str:
    entries = []
    for site in sites:
        name, target = site["package"], site["platform"]
        metrics = site["symbols"]
        entries.append(f'<li><a href="packages/{html.escape(name)}/{html.escape(target)}/html/index.html">'
                       f'{html.escape(name)} · {html.escape(target)}</a> '
                       f'<small>{metrics["documented"]}/{metrics["total"]} 项有说明</small></li>')
    scope = "此产物只包含所选的包或平台。" if partial else "包含全部生产源码包和三个目标平台。"
    return ('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Termcanvas API 参考</title><style>body{font:1rem/1.6 system-ui,sans-serif;'
            'max-width:64rem;margin:2rem auto;padding:0 1rem;color:#182334}'
            'li{margin:.5rem 0}small{color:#566273}</style>'
            '<h1>Termcanvas API 参考</h1><p>' + scope +
            '覆盖统计以各站点报告为准，语言公开性与稳定性分类不同；示例执行情况尚须单独核验。</p>'
            '<p><a href="api-inventory.json">API 分类清单</a></p><ul>' +
            ''.join(entries) + '</ul></html>\n')


def check_owned(output: Path) -> None:
    if output.is_symlink():
        raise GenerationError("output directory cannot be a symbolic link")
    if not output.exists():
        return
    marker = output / MARKER
    if not output.is_dir() or not marker.is_file():
        raise GenerationError(f"output is not a managed cjdoc portal: {output}")
    try:
        metadata = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise GenerationError("invalid output marker") from error
    if not isinstance(metadata, dict) or metadata.get("format_version") != 1:
        raise GenerationError("invalid output marker")


def replace_owned(output: Path, built: Path, temporary: Path) -> None:
    check_owned(output)
    backup = temporary / "previous"
    existed = output.exists()
    if existed:
        os.replace(output, backup)
    try:
        os.replace(built, output)
    except BaseException:
        if existed:
            os.replace(backup, output)
        raise
    if existed:
        shutil.rmtree(backup)


def generate(cjdoc: Path, output: Path, package_names: list[str], targets: list[str], partial: bool,
             sdk_env: dict[str, str], sdk_info: dict[str, str]) -> None:
    check = subprocess.run([sys.executable, str(ROOT / "scripts/api_contract.py"), "--check"], check=False)
    if check.returncode != 0:
        raise GenerationError("classified API inventory is stale")
    metadata = load_json(CLASSIFICATION)
    all_sources = production_files(metadata)
    examples, example_sources = load_examples(load_json(ROOT / "docs/api-inventory.json"))
    members = {Path(root).parts[1]: ROOT / Path(*Path(root).parts[:2]) for root in metadata["source_roots"]}
    inputs = all_sources + [CLASSIFICATION, ROOT / "docs/api-inventory.json",
                            ROOT / "scripts/api_contract.py", ROOT / "scripts/native_sdk.py", ROOT / "scripts/cjdoc_examples.py",
                            ROOT / "scripts/normalize_cjdoc_parameters.py",
                            Path(__file__).resolve()] + example_sources + [
                                member / "cjpm.toml" for member in members.values()]
    before = source_snapshot(inputs)
    if output == ROOT or output in ROOT.parents:
        raise GenerationError("output cannot contain the source repository")
    check_owned(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    env = sdk_env.copy()
    env.setdefault("cjHeapSize", "1GB")
    with tempfile.TemporaryDirectory(prefix=".termcanvas-cjdoc-", dir=output.parent) as temp:
        temporary = Path(temp)
        built = temporary / "portal"
        built.mkdir()
        sites = []
        for name in package_names:
            member = members[name]
            expected = {p.relative_to(member).as_posix() for p in all_sources if p.parent == member / "src"}
            for target in targets:
                os_name, arch = PLATFORMS[target]
                destination = built / "packages" / name / target
                destination.parent.mkdir(parents=True, exist_ok=True)
                command = [str(cjdoc), "generate", "--project", str(member), "--format", "json",
                           "--format", "html", "--format", "coverage", "--output", str(destination),
                           "--audience", "external", "--lint-profile", "standard", "--jobs", "1",
                           "--cfg", f"os={os_name}", "--cfg", f"arch={arch}", "--no-cache", "--locale", "zh-CN"]
                print(f"Generating {name} ({target})", flush=True)
                result = subprocess.run(command, env=env, check=False, capture_output=True, text=True, timeout=600)
                if result.returncode:
                    raise GenerationError(f"cjdoc failed for {name} ({target}): exit {result.returncode}\n{result.stderr[-4000:]}")
                normalized = normalize_anonymous_parameters(destination)
                doc = load_json(destination / "docs.json")
                files = {item["path"] for item in doc["files"]}
                errors = [item for item in doc["diagnostics"] if item.get("severity") == "error"]
                if doc.get("status") != "complete" or errors or files != expected:
                    raise GenerationError(f"incomplete source inventory for {name} ({target}); missing={sorted(expected-files)} extra={sorted(files-expected)} errors={len(errors)}")
                coverage = load_json(destination / "coverage" / "coverage.json")
                sites.append({"package": name, "platform": target, "symbols": coverage["metrics"]["symbols"],
                              "anonymous_parameter_repairs": normalized})
        link_examples(built, sites, examples)
        if source_snapshot(inputs) != before:
            raise GenerationError("production inputs changed while generating documentation")
        shutil.copyfile(ROOT / "docs/api-inventory.json", built / "api-inventory.json")
        (built / "index.html").write_text(portal(sites, partial), encoding="utf-8")
        (built / MARKER).write_text(json.dumps({"format_version": 1, "partial": partial, "examples_verified_at_generation": False, "cjdoc_version": VERSION,
            "cjdoc_source_revision": SOURCE_REVISION, "cjdoc_sha256": sha256(cjdoc), "sdk": sdk_info, "sources": before,
            "sites": sites}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        replace_owned(output, built, temporary)


def main() -> int:
    metadata = load_json(CLASSIFICATION)
    names = sorted({Path(root).parts[1] for root in metadata["source_roots"]})
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "target/doc")
    parser.add_argument("--cjdoc", default="cjdoc", help="path to the official cjdoc 0.7.7 executable")
    parser.add_argument("--package", action="append", choices=names, help="generate only selected packages")
    parser.add_argument("--platform", action="append", choices=sorted(PLATFORMS), help="generate only selected targets")
    args = parser.parse_args()
    packages = sorted(set(args.package or names))
    targets = sorted(set(args.platform or PLATFORMS))
    output = args.output.absolute()
    try:
        requested = os.environ.get("CANGJIE_SDK_ROOT", "")
        if not requested:
            raise GenerationError("set CANGJIE_SDK_ROOT to the Cangjie STS 1.2.0 SDK")
        sdk, sdk_env, runtime = sdk_environment(requested)
        cjc_version, cjpm_version = verify_sdk(sdk, sdk_env)
        suffix = ".exe" if os.name == "nt" else ""
        sdk_info = {"cjc_version": cjc_version, "cjpm_version": cjpm_version,
                    "cjc_sha256": sha256(sdk / "bin" / ("cjc" + suffix)),
                    "cjpm_sha256": sha256(sdk / "tools/bin" / ("cjpm" + suffix)),
                    "runtime_sha256": sha256(runtime)}
        generate(qualified_cjdoc(args.cjdoc, sdk_env), output, packages, targets,
                 packages != names or targets != sorted(PLATFORMS), sdk_env, sdk_info)
    except (GenerationError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"generated {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
