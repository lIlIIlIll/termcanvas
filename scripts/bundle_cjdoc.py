#!/usr/bin/env python3
"""Create a reproducible offline archive from a validated cjdoc portal."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile

from audit_cjdoc import audit
from check_cjdoc_links import check


def bundle(portal: Path, output: Path) -> str:
    portal = portal.resolve()
    output = output.parent.resolve() / output.name
    if output.is_relative_to(portal):
        raise ValueError("archive must be outside the generated portal")
    if output.exists() or output.is_symlink():
        raise ValueError("archive already exists")
    audit(portal)
    checked, errors = check(portal)
    if errors:
        raise ValueError(f"portal has {len(errors)} broken local links")
    files = sorted(p for p in portal.rglob("*") if p.is_file() or p.is_symlink())
    if any(path.is_symlink() for path in files):
        raise ValueError("portal contains symbolic links")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".termcanvas-archive-", dir=output.parent) as temp:
        archive = Path(temp) / "archive.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as writer:
            for path in files:
                info = zipfile.ZipInfo(path.relative_to(portal).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                with path.open("rb") as source, writer.open(info, "w") as target:
                    shutil.copyfileobj(source, target)
        digest = hashlib.sha256()
        with archive.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(block)
        audit(portal)
        os.link(archive, output)
    print(f"checked {checked} local links; archived {len(files)} files")
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("portal", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        digest = bundle(args.portal, args.output)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"sha256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
