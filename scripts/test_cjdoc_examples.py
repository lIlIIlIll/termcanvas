#!/usr/bin/env python3
"""Compile and run the documented downstream testing example."""

from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import tempfile

from native_sdk import sdk_environment, verify_sdk
from new_example import create_application

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    source = (ROOT / "packages/testing/src/testing.cj").read_text(encoding="utf-8")
    matches = re.findall(
        r"@example (?:检查渲染内容|组合任务状态与进度条)\n \* ```cangjie\n(?P<code>(?: \* .*\n)+?) \* ```",
        source,
    )
    if len(matches) != 2:
        raise RuntimeError("expected both documented testing examples")
    code = "\n".join(
        "".join(line.removeprefix(" * ") for line in match.splitlines(keepends=True))
        for match in matches
    )
    sdk, env, _ = sdk_environment(os.environ.get("CANGJIE_SDK_ROOT", ""))
    verify_sdk(sdk, env)
    suffix = ".exe" if os.name == "nt" else ""
    cjpm = sdk / "tools/bin" / ("cjpm" + suffix)
    with tempfile.TemporaryDirectory(prefix="termcanvas-cjdoc-example-") as temporary:
        work = Path(temporary)
        app = create_application("cjdoc_probe", work / "consumer", ROOT, script_dir=work / "scripts")
        (app / "src/main.cj").write_text(
            "package cjtui_cjdoc_probe\n\nimport core.*\nimport cjtui_testing.*\n\n"
            "main(): Int64 {\n" + code + "\n    0\n}\n", encoding="utf-8"
        )
        target = work / "build"
        subprocess.run([str(cjpm), "build", "--target-dir", str(target)],
                       cwd=app, env=env, check=True, timeout=300)
        subprocess.run([str(target / "release/bin" / ("main" + suffix))],
                       cwd=app, env=env, check=True, timeout=30)
    print("both documented downstream examples built and ran successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
