#!/usr/bin/env python3
"""Resolve and optionally install the Cangjie nightly SDK for CI.

The local developer helper at ``~/.local/bin/get_sdk.py`` contains the richer
interactive DevRepo downloader. This repository script keeps the CI subset
self-contained: explicit archive URLs are preferred, and DevRepo latest lookup
is available when CI provides a token.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


PROJECT_ID = "44e9333d2f2d4b25802e4a62beb611b2"
REGION = "cn-north-4"
TOKEN_ENV = "TOKEN"
DEFAULT_CHANNEL = "main"
DYNAMIC_LATEST_CHANNELS = {"main"}
DYNAMIC_CHANNEL_PACKAGE_PREFIXES = {"main": "1.1.0-alpha"}
CHANNEL_PACKAGE_VERSIONS = {
    "main": "1.1.0-alpha",
    "dev": "1.1.0-alpha.20260527010056",
    "release-1.0": "1.0.5",
    "release-1.1": "1.1.0-alpha.20260602054550",
    "openharmony-6.0": "1.1.0-beta.2",
}
CHANNEL_ALIASES = {
    "master": "main",
    "release_1_0": "release-1.0",
    "release10": "release-1.0",
    "release-10": "release-1.0",
    "1.0": "release-1.0",
    "release_1_1": "release-1.1",
    "release11": "release-1.1",
    "release-11": "release-1.1",
    "1.1": "release-1.1",
    "openharmony": "openharmony-6.0",
    "openharmony_6_0": "openharmony-6.0",
    "openharmony-60": "openharmony-6.0",
}


@dataclass(frozen=True)
class SdkCandidate:
    version: str
    url: str
    name: str


def normalize_channel(value: str) -> str:
    key = value.strip().lower().replace("/", "-")
    key = CHANNEL_ALIASES.get(key, key)
    if key == "auto":
        return DEFAULT_CHANNEL
    if key not in CHANNEL_PACKAGE_VERSIONS:
        raise SystemExit(f"unsupported channel: {value}")
    return key


def arch_norm(value: str) -> str:
    low = value.lower()
    return "aarch64" if low == "arm64" else low


def sdk_prefix(os_name: str, arch: str) -> str:
    return f"cangjie-sdk-{os_name.lower()}-{arch_norm(arch)}-"


def version_prefix(channel: str) -> str:
    if channel in DYNAMIC_LATEST_CHANNELS:
        return DYNAMIC_CHANNEL_PACKAGE_PREFIXES[channel]
    return CHANNEL_PACKAGE_VERSIONS[channel]


def extract_version(text: str) -> str:
    clean = re.sub(r"\.(?:tar\.gz|tgz|zip)$", "", text)
    match = re.search(r"(1\.\d+\.\d+(?:-[A-Za-z0-9.]+)?)", clean)
    if match:
        return match.group(1).rstrip(".")
    date = re.search(r"(20\d{12,})", clean)
    if date:
        return date.group(1)
    return "unknown"


def candidate_sort_key(candidate: SdkCandidate) -> tuple[str, str]:
    return (candidate.version, candidate.name)


def explicit_candidate(url: str) -> SdkCandidate:
    name = Path(urllib.parse.urlparse(url).path).name or "sdk-archive"
    return SdkCandidate(extract_version(url), url, name)


def version_matches(candidate_version: str, channel: str, requested_version: str) -> bool:
    if requested_version:
        return candidate_version == requested_version
    return candidate_version.startswith(version_prefix(channel))


def load_manifest(
    path: Path, os_name: str, arch: str, channel: str, requested_version: str = ""
) -> SdkCandidate:
    data = json.loads(path.read_text(encoding="utf-8"))
    prefix = sdk_prefix(os_name, arch)
    wanted_version = requested_version or version_prefix(channel)
    candidates: list[SdkCandidate] = []
    for item in data if isinstance(data, list) else data.get("files", []):
        name = str(item.get("name") or item.get("real_name") or item.get("filename") or "")
        url = str(item.get("url") or item.get("download_url") or "")
        version = str(item.get("version") or item.get("package_version") or extract_version(name))
        if name.startswith(prefix) and version_matches(version, channel, requested_version) and url:
            candidates.append(SdkCandidate(version, url, name))
    if not candidates:
        raise SystemExit(f"manifest has no SDK matching {prefix} and {wanted_version}")
    return sorted(candidates, key=candidate_sort_key, reverse=True)[0]


def devrepo_latest(
    os_name: str, arch: str, channel: str, token: str, requested_version: str = ""
) -> SdkCandidate:
    prefix = sdk_prefix(os_name, arch)
    wanted_version = requested_version or version_prefix(channel)
    query = urllib.parse.urlencode({"search_name": wanted_version})
    url = (
        f"https://devrepo.devcloud.huaweicloud.com/devreposerver/v5/files/list"
        f"?region={REGION}&project_id={PROJECT_ID}&{query}"
    )
    request = urllib.request.Request(url, headers={"X-Auth-Token": token})
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    files = payload.get("result") or payload.get("files") or payload.get("data") or []
    candidates: list[SdkCandidate] = []
    for item in files:
        name = str(item.get("real_name") or item.get("name") or "")
        download_url = str(item.get("download_url") or item.get("url") or "")
        version = str(item.get("package_version") or item.get("version") or extract_version(name))
        if (
            name.startswith(prefix)
            and version_matches(version, channel, requested_version)
            and download_url
        ):
            candidates.append(SdkCandidate(version, download_url, name))
    if not candidates:
        raise SystemExit(f"DevRepo returned no SDK matching {prefix} and {wanted_version}")
    return sorted(candidates, key=candidate_sort_key, reverse=True)[0]


def resolve(args: argparse.Namespace) -> SdkCandidate:
    requested_version = getattr(args, "version", "").strip()
    if args.url:
        candidate = explicit_candidate(args.url)
        if (
            requested_version
            and candidate.version != "unknown"
            and candidate.version != requested_version
        ):
            raise SystemExit(
                f"explicit SDK version {candidate.version} does not match requested {requested_version}"
            )
        return candidate
    channel = normalize_channel(args.channel)
    if args.manifest:
        return load_manifest(
            Path(args.manifest), args.os, args.arch, channel, requested_version
        )
    token = os.environ.get(TOKEN_ENV, "")
    if token:
        return devrepo_latest(args.os, args.arch, channel, token, requested_version)
    env_url = os.environ.get("CANGJIE_SDK_URL", "")
    if env_url:
        candidate = explicit_candidate(env_url)
        if (
            requested_version
            and candidate.version != "unknown"
            and candidate.version != requested_version
        ):
            raise SystemExit(
                f"explicit SDK version {candidate.version} does not match requested {requested_version}"
            )
        return candidate
    raise SystemExit(
        "no SDK source: set CANGJIE_SDK_URL, pass --url/--manifest, or provide TOKEN for DevRepo lookup"
    )


def safe_extract(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    if archive.suffix == ".zip":
        with zipfile.ZipFile(archive) as zf:
            for member in zf.infolist():
                target = (dest / member.filename).resolve()
                if not str(target).startswith(str(dest.resolve())):
                    raise SystemExit(f"unsafe zip path: {member.filename}")
            zf.extractall(dest)
        return
    with tarfile.open(archive, "r:*") as tf:
        for member in tf.getmembers():
            target = (dest / (member.name or "")).resolve()
            if not str(target).startswith(str(dest.resolve())):
                raise SystemExit(f"unsafe tar path: {member.name}")
        tf.extractall(dest)


def download(url: str, dest: Path) -> None:
    with urllib.request.urlopen(url, timeout=60) as response, dest.open("wb") as out:
        shutil.copyfileobj(response, out)


def install(candidate: SdkCandidate, install_dir: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="cj-sdk-") as tmp:
        archive = Path(tmp) / (candidate.name or "sdk.tar.gz")
        download(candidate.url, archive)
        safe_extract(archive, install_dir)


def emit_github_env(install_dir: Path, version: str) -> None:
    github_path = os.environ.get("GITHUB_PATH")
    github_env = os.environ.get("GITHUB_ENV")
    old_library_path = os.environ.get("LD_LIBRARY_PATH", "")
    if github_path:
        with open(github_path, "a", encoding="utf-8") as fh:
            fh.write(f"{install_dir / 'bin'}\n")
            fh.write(f"{install_dir / 'tools/bin'}\n")
    if github_env:
        with open(github_env, "a", encoding="utf-8") as fh:
            fh.write(f"CANGJIE_HOME={install_dir}\n")
            fh.write(f"CANGJIE_SDK_ROOT={install_dir}\n")
            fh.write(f"CJ_TUI_NIGHTLY_SDK_VERSION={version}\n")
            fh.write(
                f"LD_LIBRARY_PATH={install_dir / 'lib'}:{install_dir / 'runtime/lib'}:{old_library_path}\n"
            )


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--channel", default=os.environ.get("CANGJIE_SDK_CHANNEL", DEFAULT_CHANNEL))
    parser.add_argument("--version", default=os.environ.get("CANGJIE_SDK_VERSION", ""))
    parser.add_argument("--os", default=os.environ.get("CANGJIE_SDK_OS", "linux"))
    parser.add_argument("--arch", default=os.environ.get("CANGJIE_SDK_ARCH", "x64"))
    parser.add_argument("--url", default=os.environ.get("CANGJIE_SDK_URL", ""))
    parser.add_argument("--manifest", default=os.environ.get("CANGJIE_SDK_MANIFEST", ""))
    parser.add_argument("--install-dir", default=os.environ.get("CANGJIE_SDK_INSTALL_DIR", ""))
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--emit-github-env", action="store_true")
    args = parser.parse_args(list(argv))

    candidate = resolve(args)
    print(json.dumps(candidate.__dict__, ensure_ascii=False, sort_keys=True))
    if args.install:
        install_dir = Path(args.install_dir or os.environ.get("RUNNER_TEMP", "/tmp")) / "cangjie-sdk"
        if install_dir.exists():
            shutil.rmtree(install_dir)
        install(candidate, install_dir)
        if args.emit_github_env:
            emit_github_env(install_dir, candidate.version)
        subprocess.run([str(install_dir / "bin" / "cjc"), "-v"], check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
