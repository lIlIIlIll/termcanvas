#!/usr/bin/env python3
"""Self-contained native package and downstream validation on hosted runners."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def call(*command: str) -> None:
    print("==> " + " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> int:
    call(sys.executable, "scripts/native_sdk.py", "--report")
    call(sys.executable, "scripts/check_version.py")
    for package in ("core", "terminal", "diff", "game", "media", "markdown_adapter", "testing"):
        call(sys.executable, "scripts/native_sdk.py", "--run", str(ROOT / "packages" / package),
             "--", "cjpm", "test", "--no-color")
    call(sys.executable, "scripts/test_downstream_app.py")
    call(sys.executable, "scripts/native_terminal_harness.py")
    print("native platform checks passed", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
