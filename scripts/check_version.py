#!/usr/bin/env python3
"""Keep active first-party manifests aligned with the release version."""
from pathlib import Path
import sys
import tomllib

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    expected = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    bad = []
    manifests = []
    for folder in ("packages", "examples", "templates", "tests/fixtures"):
        manifests.extend((ROOT / folder).glob("*/cjpm.toml"))
    for path in sorted(manifests):
        actual = tomllib.loads(path.read_text(encoding="utf-8"))["package"]["version"]
        if actual != expected:
            bad.append(f"{path.relative_to(ROOT)}: expected {expected}, got {actual}")
    if bad:
        print("\n".join(bad), file=sys.stderr)
        return 1
    print(f"release version {expected}: {len(manifests)} first-party manifests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
