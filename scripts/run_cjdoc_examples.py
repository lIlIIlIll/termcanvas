#!/usr/bin/env python3
"""Build shared API examples as downstream applications on the current platform."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import tomllib

from api_contract import CLASSIFICATION, ROOT, load_json, production_files
from cjdoc_examples import load_examples
from generate_cjdoc import sha256, source_snapshot
from native_sdk import sdk_environment, verify_sdk
from new_example import create_application, dependency_path

HOST_TARGET = {"Linux": "linux", "Darwin": "macos", "Windows": "windows"}


def run_scenario(scenario: dict, sdk: Path, env: dict[str, str], packages: set[str]) -> dict:
    name = scenario["id"]
    source = ROOT / scenario["source"]
    result = {"id": name, "source": scenario["source"], "source_sha256": sha256(source)}
    target = HOST_TARGET.get(platform.system())
    if target not in scenario["platforms"]:
        result["status"] = "not_applicable"
        return result
    dependencies = scenario["dependencies"]
    if len(set(dependencies)) != len(dependencies) or not set(dependencies) <= packages:
        raise ValueError(f"unknown or duplicate example dependency: {name}")
    suffix = ".exe" if os.name == "nt" else ""
    cjpm = sdk / "tools/bin" / ("cjpm" + suffix)
    with tempfile.TemporaryDirectory(prefix="termcanvas-api-example-") as temporary:
        work = Path(temporary)
        app = create_application("api_example", work / "consumer", ROOT, script_dir=work / "scripts")
        manifest = app / "cjpm.toml"
        text = manifest.read_text(encoding="utf-8")
        for package in dependencies:
            if package in ("core", "testing"):
                continue
            path = dependency_path(ROOT / "packages" / package, app, "relative")
            text += f'\n  {json.dumps(package)} = {{ path = {json.dumps(path)}, output-type = "static" }}\n'
        if "markdown_adapter" in dependencies:
            adapter = tomllib.loads((ROOT / "packages/markdown_adapter/cjpm.toml").read_text(encoding="utf-8"))
            markdown = adapter.get("dependencies", {}).get("markdown")
            if not isinstance(markdown, dict) or set(markdown) != {"git", "tag", "output-type"} or not all(
                    isinstance(value, str) and value for value in markdown.values()):
                raise ValueError("unsupported markdown adapter dependency")
            fields = ", ".join(f"{json.dumps(key)} = {json.dumps(value)}" for key, value in markdown.items())
            text += f'\n  "markdown" = {{ {fields} }}\n'
        manifest.write_text(text, encoding="utf-8")
        (app / "src/main.cj").write_bytes(source.read_bytes())
        build = work / "build"
        commands = ([str(cjpm), "build", "--target-dir", str(build)],
                    [str(build / "release/bin" / ("main" + suffix))])
        for command in commands:
            completed = subprocess.run(command, cwd=app, env=env, capture_output=True, text=True,
                                       timeout=300, check=False)
            if completed.returncode != 0:
                print(f"example {name} failed: exit {completed.returncode}\n{completed.stderr[-4000:]}", file=sys.stderr)
                result["status"] = "failed"
                return result
    result["status"] = "passed"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True, help="new JSON evidence file")
    parser.add_argument("--scenario", action="append", help="run only selected example ids")
    args = parser.parse_args()
    try:
        requested = os.environ.get("CANGJIE_SDK_ROOT", "")
        if not requested:
            raise ValueError("set CANGJIE_SDK_ROOT to the Cangjie STS 1.2.0 SDK")
        sdk, env, runtime = sdk_environment(requested)
        cjc_version, cjpm_version = verify_sdk(sdk, env)
        metadata = load_json(CLASSIFICATION)
        inventory = load_json(ROOT / "docs/api-inventory.json")
        scenarios, sources = load_examples(inventory)
        if args.scenario:
            wanted = set(args.scenario)
            if wanted - {scenario["id"] for scenario in scenarios}:
                raise ValueError("unknown example id")
            scenarios = [scenario for scenario in scenarios if scenario["id"] in wanted]
        if not scenarios:
            raise ValueError("no examples selected")
        packages = {Path(root).parts[1] for root in metadata["source_roots"]}
        inputs = production_files(metadata) + sources + [CLASSIFICATION, ROOT / "docs/api-inventory.json",
            ROOT / "scripts/api_contract.py", ROOT / "scripts/generate_cjdoc.py", ROOT / "scripts/native_sdk.py",
            ROOT / "scripts/new_example.py", ROOT / "scripts/cjdoc_examples.py", ROOT / "scripts/audit_cjdoc.py",
            ROOT / "scripts/check_cjdoc_completion.py", ROOT / "scripts/check_cjdoc_links.py",
            ROOT / "scripts/bundle_cjdoc.py", ROOT / "scripts/prepare_cjdoc_publication.py",
            ROOT / ".github/workflows/api-docs.yml", Path(__file__).resolve()] + [
                ROOT / Path(*Path(path).parts[:2]) / "cjpm.toml" for path in metadata["source_roots"]]
        before = source_snapshot(inputs)
        results = []
        for scenario in scenarios:
            print(f'Running {scenario["id"]}', flush=True)
            results.append(run_scenario(scenario, sdk, env, packages))
        if source_snapshot(inputs) != before:
            raise ValueError("source inputs changed while examples were running")
        host = HOST_TARGET.get(platform.system())
        if host is None:
            raise ValueError("unsupported execution platform")
        suffix = ".exe" if os.name == "nt" else ""
        report = {"format_version": 1, "platform": host, "machine": platform.machine(),
                  "selected": bool(args.scenario), "sdk": {"cjc_version": cjc_version,
                  "cjpm_version": cjpm_version, "runtime_sha256": sha256(runtime),
                  "cjc_sha256": sha256(sdk / "bin" / ("cjc" + suffix)),
                  "cjpm_sha256": sha256(sdk / "tools/bin" / ("cjpm" + suffix))},
                  "sources": before, "sources_sha256": hashlib.sha256(json.dumps(before, sort_keys=True).encode("utf-8")).hexdigest(),
                  "results": results}
        with args.report.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        failed = any(result["status"] == "failed" for result in results)
        print(f"example report: {args.report}")
        return 1 if failed else 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
