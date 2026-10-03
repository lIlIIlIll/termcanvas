#!/usr/bin/env python3
"""Create a repository example or an independent termcanvas application."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]


def dependency_path(package: Path, destination: Path, mode: str) -> str:
    if mode == "absolute":
        return package.as_posix()
    try:
        return Path(os.path.relpath(package, destination)).as_posix()
    except ValueError:
        # Windows cannot express a relative dependency across drive letters.
        return package.as_posix()


def create_application(name: str, destination: Path, library: Path,
                       path_mode: str = "relative", script_dir: Path | None = None) -> Path:
    if re.fullmatch(r"[a-z][a-z0-9_]*", name) is None:
        raise ValueError("application name must match [a-z][a-z0-9_]*")
    library = library.expanduser().resolve()
    # Keep the final component un-resolved so a dangling destination symlink
    # remains an existing object and can never redirect the generator.
    destination = destination.expanduser().absolute()
    destination = destination.parent.resolve() / destination.name
    for package in ("core", "testing"):
        if not (library / "packages" / package / "cjpm.toml").is_file():
            raise ValueError(f"library root lacks packages/{package}/cjpm.toml: {library}")
    template = ROOT / "templates" / "basic_app"
    sources = [Path("cjpm.toml"), Path("src/main.cj"), Path("src/main_test.cj")]
    content = {path: (template / path).read_text(encoding="utf-8") for path in sources}
    if script_dir is not None:
        script_dir = script_dir.expanduser().resolve()
        if os.name == "nt" and any(char.isspace() for char in str(script_dir)):
            raise ValueError("Cangjie 1.1.3 on Windows requires --script-dir without spaces")
        content[Path("cjpm.toml")] = content[Path("cjpm.toml")].replace(
            'script-dir = ""', 'script-dir = ' + json.dumps(script_dir.as_posix())
        )
    for package in ("core", "testing"):
        old = json.dumps(f"../../packages/{package}")
        value = dependency_path(library / "packages" / package, destination, path_mode)
        content[Path("cjpm.toml")] = content[Path("cjpm.toml")].replace(old, json.dumps(value))
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.mkdir()  # Fails for files, directories and dangling symlinks.
    try:
        (destination / "src").mkdir()
        for path, text in content.items():
            (destination / path).write_text(
                text.replace("cjtui_basic_app", "cjtui_" + name), encoding="utf-8"
            )
    except BaseException:
        shutil.rmtree(destination)
        raise
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("--output", type=Path, help="exact new application directory; default examples/NAME")
    parser.add_argument("--library-root", type=Path, default=ROOT,
                        help="termcanvas source checkout providing packages/core and packages/testing")
    parser.add_argument("--dependency-path", choices=("relative", "absolute"), default="relative")
    parser.add_argument("--script-dir", type=Path,
                        help="build-script output directory; use a path without spaces on Windows")
    args = parser.parse_args()
    if re.fullmatch(r"[a-z][a-z0-9_]*", args.name) is None:
        parser.error("application name must match [a-z][a-z0-9_]*")
    try:
        destination = args.output if args.output is not None else ROOT / "examples" / args.name
        create_application(args.name, destination, args.library_root, args.dependency_path,
                           script_dir=args.script_dir)
    except (OSError, ValueError) as error:
        print(f"cannot create application: {error}", file=sys.stderr)
        return 1
    print(f"created {destination if args.output is not None else 'examples/' + args.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
