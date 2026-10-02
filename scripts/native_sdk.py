#!/usr/bin/env python3
"""Pinned native SDK environment and argv-safe runner for every CI platform."""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

SDK_VERSION = "1.1.3"


def native_path(value: str) -> Path:
    if os.name == "nt" and re.match(r"^/[A-Za-z]/", value):
        value = value[1].upper() + ":/" + value[3:]
    return Path(value).expanduser().resolve()


def sdk_environment(root: str, *, system: str | None = None,
                    machine: str | None = None) -> tuple[Path, dict[str, str], Path]:
    system = system or platform.system()
    machine = (machine or platform.machine()).lower()
    arch = {"amd64": "x86_64", "arm64": "aarch64"}.get(machine, machine)
    suffix = ".exe" if system == "Windows" else ""
    path = native_path(root)
    if not (path / "bin" / ("cjc" + suffix)).is_file() and (path / "cangjie").is_dir():
        path = path / "cangjie"
    prefixes = {"Linux": ["linux"], "Darwin": ["darwin"], "Windows": ["windows", "win32"]}
    if system not in prefixes:
        raise ValueError(f"unsupported native SDK platform: {system}")
    runtime_dirs = [path / "runtime" / "lib" / f"{p}_{arch}_cjnative" for p in prefixes[system]]
    extension = {"Linux": ".so", "Darwin": ".dylib", "Windows": ".dll"}[system]
    runtimes = [p for d in runtime_dirs for p in d.glob("*cangjie-runtime*" + extension) if p.is_file()]
    if len(runtimes) != 1:
        raise ValueError(f"expected one {system}/{arch} Cangjie runtime in {path}; found {len(runtimes)}")
    for command in (path / "bin" / ("cjc" + suffix), path / "tools" / "bin" / ("cjpm" + suffix)):
        if not command.is_file():
            raise ValueError(f"incomplete Cangjie SDK: missing {command}")
    runtime = runtimes[0]
    env = os.environ.copy()
    env.update({name: str(path) for name in ("CANGJIE_HOME", "CANGJIE_ROOT", "CANGJIE_PATH", "CANGJIE_SDK_ROOT")})
    libs = [runtime.parent, path / "tools" / "lib", path / "lib" / runtime.parent.name]
    lib_paths = [str(p) for p in libs if p.is_dir()]
    bins = [str(path / "bin"), str(path / "tools" / "bin")]
    env["PATH"] = os.pathsep.join(bins + (lib_paths if system == "Windows" else []) + [env.get("PATH", "")])
    if system != "Windows":
        key = "DYLD_LIBRARY_PATH" if system == "Darwin" else "LD_LIBRARY_PATH"
        env[key] = os.pathsep.join(lib_paths)
    if system == "Darwin" and not env.get("SDKROOT"):
        found = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"],
                               capture_output=True, text=True, check=True, timeout=15)
        env["SDKROOT"] = found.stdout.strip()
    env["DISABLE_ZOXIDE"] = "1"
    return path, env, runtime


def verify_sdk(path: Path, env: dict[str, str]) -> tuple[str, str]:
    suffix = ".exe" if os.name == "nt" else ""
    versions = []
    for relative, flag in (("bin/cjc", "-v"), ("tools/bin/cjpm", "--version")):
        result = subprocess.run([str(path / (relative + suffix)), flag], env=env,
                                capture_output=True, text=True, timeout=30)
        output = (result.stdout + result.stderr).strip()
        pattern = r"(?<![0-9.])" + re.escape(SDK_VERSION) + r"(?![0-9.])"
        if result.returncode or not re.search(pattern, output):
            raise ValueError(f"unsupported {relative}; expected {SDK_VERSION}, got: {output}")
        versions.append(output)
    return versions[0], versions[1]


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--run", metavar="WORKDIR")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        requested = os.environ.get("CANGJIE_SDK_ROOT", "")
        if not requested:
            raise ValueError("set CANGJIE_SDK_ROOT to the pinned Cangjie STS SDK")
        root, env, runtime = sdk_environment(requested)
        cjc, cjpm = verify_sdk(root, env)
        suffix = ".exe" if os.name == "nt" else ""
        if args.run:
            command = args.command
            if command[:1] == ["--"]:
                command = command[1:]
            if not command:
                raise ValueError("--run requires a command")
            workdir = native_path(args.run)
            name = Path(command[0]).name.removesuffix(".exe")
            if name in ("cjc", "cjpm"):
                command[0] = str(root / ("tools/bin" if name == "cjpm" else "bin") / (name + suffix))
            if (name == "cjpm" and len(command) > 1 and command[1] in ("bench", "build", "run", "test")
                    and env.get("CJ_TUI_CANONICAL_TARGET_ROOT") and "--target-dir" not in command):
                key = hashlib.sha256(str(workdir).encode()).hexdigest()[:16]
                target = native_path(env["CJ_TUI_CANONICAL_TARGET_ROOT"]) / key
                target.mkdir(parents=True, exist_ok=True)
                command += ["--target-dir", str(target)]
            return subprocess.run(command, cwd=workdir, env=env, check=False).returncode
        if args.report:
            print(f"CANGJIE_SDK_ROOT={root}")
            print("CJC_VERSION=" + cjc.replace("\n", "; "))
            print("CJC_SHA256=" + digest(root / ("bin/cjc" + suffix)))
            print("CJPM_VERSION=" + cjpm.replace("\n", "; "))
            print(f"RUNTIME={runtime}")
            print("RUNTIME_SHA256=" + digest(runtime))
        else:
            print(root)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"cjtui: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
