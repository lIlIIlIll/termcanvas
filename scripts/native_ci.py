#!/usr/bin/env python3
"""Self-contained native package and downstream validation on hosted runners."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def call(*command: str) -> None:
    print("==> " + " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True, timeout=900)


def main() -> int:
    call(sys.executable, "scripts/native_sdk.py", "--report")
    call(sys.executable, "scripts/check_version.py")
    call(sys.executable, "scripts/test_native_sdk.py")
    call(sys.executable, "scripts/test_windows_terminal_harness.py")
    call(sys.executable, "packages/core/native/test_spawn.py")
    for package in ("core", "terminal", "diff", "game", "media", "markdown_adapter", "testing"):
        call(sys.executable, "scripts/native_sdk.py", "--run", str(ROOT / "packages" / package),
             "--", "cjpm", "test", "--no-color")
    call(sys.executable, "scripts/test_downstream_app.py")
    report = Path(os.environ.get("CJ_TUI_CANONICAL_TARGET_ROOT", ROOT / "target")) / "native-terminal.json"
    call(sys.executable, "scripts/native_terminal_harness.py", "--output", str(report))
    print("native platform checks passed", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
    except subprocess.TimeoutExpired as error:
        print(f"native validation timed out after {error.timeout}s: {error.cmd}", file=sys.stderr)
        raise SystemExit(1)
