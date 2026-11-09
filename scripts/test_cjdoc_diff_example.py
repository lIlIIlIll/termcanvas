#!/usr/bin/env python3
"""Compile and run the documented diff example as a downstream application."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from native_sdk import sdk_environment, verify_sdk
from new_example import create_application, dependency_path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    source = (ROOT / "packages/diff/src/diff.cj").read_text(encoding="utf-8")
    matches = re.findall(
        r"@example 解析并显示差异\n \* ```cangjie\n(?P<code>(?: \* .*\n)+?) \* ```",
        source,
    )
    if len(matches) != 1:
        raise RuntimeError("expected the documented diff example")
    code = "".join(line.removeprefix(" * ") for line in matches[0].splitlines(keepends=True))
    sdk, env, _ = sdk_environment(os.environ.get("CANGJIE_SDK_ROOT", ""))
    verify_sdk(sdk, env)
    suffix = ".exe" if os.name == "nt" else ""
    cjpm = sdk / "tools/bin" / ("cjpm" + suffix)
    with tempfile.TemporaryDirectory(prefix="termcanvas-diff-doc-example-") as temporary:
        work = Path(temporary)
        app = create_application("cjdoc_diff", work / "consumer", ROOT, script_dir=work / "scripts")
        manifest = app / "cjpm.toml"
        diff_path = dependency_path(ROOT / "packages/diff", app, "relative")
        manifest.write_text(manifest.read_text(encoding="utf-8") +
            '\n  "diff" = { path = ' + json.dumps(diff_path) + ', output-type = "static" }\n', encoding="utf-8")
        (app / "src/main.cj").write_text(
            "package cjtui_cjdoc_diff\n\nimport core.*\nimport diff.*\nimport cjtui_testing.*\n\n"
            "main(): Int64 {\n" + code + "\n    0\n}\n", encoding="utf-8")
        target = work / "build"
        subprocess.run([str(cjpm), "build", "--target-dir", str(target)], cwd=app, env=env, check=True, timeout=300)
        subprocess.run([str(target / "release/bin" / ("main" + suffix))], cwd=app, env=env, check=True, timeout=30)
    print("documented diff example built and ran successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
