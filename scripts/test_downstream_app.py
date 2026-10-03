#!/usr/bin/env python3
"""Build, test, and run a generated application outside the source checkout."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from new_example import create_application
from native_sdk import sdk_environment, verify_sdk

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library-root", type=Path, default=ROOT)
    args = parser.parse_args()
    root, env, _ = sdk_environment(os.environ.get("CANGJIE_SDK_ROOT", ""))
    verify_sdk(root, env)
    suffix = ".exe" if os.name == "nt" else ""
    cjpm = root / "tools" / "bin" / ("cjpm" + suffix)
    with tempfile.TemporaryDirectory(prefix="termcanvas-downstream-") as temporary:
        application = Path(temporary) / "standalone app"
        create_application("downstream_probe", application, args.library_root,
                           script_dir=Path(temporary) / "build-scripts")
        target = Path(temporary) / "build"
        for operation in ("build", "test"):
            subprocess.run([str(cjpm), operation, "--target-dir", str(target)],
                           cwd=application, env=env, check=True, timeout=300)
        binary = target / "release" / "bin" / ("main" + suffix)
        completed = subprocess.run([str(binary), "--headless-smoke"], cwd=application,
                                   env=env, check=True, capture_output=True, text=True, timeout=30)
        if "downstream app smoke ok" not in completed.stdout:
            raise RuntimeError("generated application did not confirm successful startup and exit")
        print(completed.stdout.strip())
    print("independent downstream build/test/run passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
