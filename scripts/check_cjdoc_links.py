#!/usr/bin/env python3
"""Check local HTML links and anchors in a generated cjdoc portal."""
from __future__ import annotations

import argparse
from html.parser import HTMLParser
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if not value:
                continue
            if name == "id" or (tag == "a" and name == "name"):
                self.ids.add(value)
            elif name in ("href", "src"):
                self.links.append(value)


def parse_page(path: Path) -> Page:
    result = Page()
    result.feed(path.read_text(encoding="utf-8"))
    return result


def check(root: Path) -> tuple[int, list[str]]:
    root = root.resolve()
    if not (root / "index.html").is_file():
        raise ValueError("portal does not contain index.html")
    pages = {p.resolve(): parse_page(p) for p in root.rglob("*.html")}
    checked = 0
    errors = []
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            checked += 1
            if url.path.startswith("/"):
                errors.append(f"{path.relative_to(root)}: absolute local URL {link}")
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            if not target.is_relative_to(root):
                errors.append(f"{path.relative_to(root)}: link leaves portal: {link}")
                continue
            if target.is_dir():
                target = target / "index.html"
            if not target.is_file():
                errors.append(f"{path.relative_to(root)}: missing target {link}")
                continue
            if url.fragment and target.suffix.lower() == ".html":
                target_page = pages.get(target)
                if target_page is None or unquote(url.fragment) not in target_page.ids:
                    errors.append(f"{path.relative_to(root)}: missing anchor {link}")
    return checked, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("portal", type=Path)
    args = parser.parse_args()
    try:
        checked, errors = check(args.portal)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"checked {checked} local links; {len(errors)} errors")
    for error in errors[:30]:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
