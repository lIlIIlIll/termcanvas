"""Repair cjdoc 0.7.7 output for multiple anonymous parameters.

An explicit @param _N tag describes the Nth parameter. Only declarations
whose parameters are all anonymous and have a complete, unique tag set are
changed. Record the repair in the JSON and render it on the symbol page.
"""
from __future__ import annotations

import html
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


TAG = re.compile(r"^_([0-9]+)$")
ROW = re.compile(r'<div class="parameter-row">.*?</div>', re.DOTALL)
EMPTY_DESCRIPTION = '<dd class="parameter-description"></dd>'


def normalize(destination: Path) -> int:
    docs_path = destination / "docs.json"
    doc = json.loads(docs_path.read_text(encoding="utf-8"))
    site = destination / "html"
    entries = json.loads((site / "symbol-index.json").read_text(encoding="utf-8"))["entries"]
    by_id = {entry["id"]: entry for entry in entries}
    count = 0
    for declaration in doc["declarations"]:
        parameters = declaration.get("parameters", [])
        if len(parameters) < 2 or any(parameter.get("name") != "_" for parameter in parameters):
            continue
        tags = (declaration.get("documentation") or {}).get("tags", [])
        indexed = [tag for tag in tags if tag.get("name") == "param" and TAG.fullmatch(tag.get("subject") or "")]
        if not indexed:
            continue
        mapping: dict[int, str] = {}
        for tag in indexed:
            index = int(TAG.fullmatch(tag["subject"]).group(1))
            description = tag.get("description") or ""
            if index in mapping or not description.strip():
                raise ValueError("invalid anonymous parameter documentation")
            mapping[index] = description
        if set(mapping) != set(range(len(parameters))):
            continue
        if any(p.get("documentation") for p in parameters):
            raise ValueError("conflicting anonymous parameter documentation")
        entry = by_id.get(declaration["id"])
        if entry is None:
            raise ValueError("anonymous parameter symbol page is missing")
        href = urlsplit(entry["href"])
        page = (site / unquote(href.path)).resolve()
        if href.scheme or href.netloc or not page.is_relative_to(site.resolve()) or not page.is_file():
            raise ValueError("invalid anonymous parameter symbol page")
        text = page.read_text(encoding="utf-8")
        start_marker = '<dl class="parameter-list">'
        start = text.find(start_marker)
        end = text.find('</dl>', start)
        if start < 0 or end < 0 or text.find(start_marker, start + 1) >= 0:
            raise ValueError("unexpected anonymous parameter page layout")
        section = text[start:end]
        rows = list(ROW.finditer(section))
        if len(rows) != len(parameters):
            raise ValueError("anonymous parameter page count mismatch")
        for index, row in reversed(list(enumerate(rows))):
            original = row.group()
            if original.count(EMPTY_DESCRIPTION) != 1:
                raise ValueError("anonymous parameter page has conflicting content")
            description = html.escape(mapping[index])
            replacement = (f'<dd class="parameter-description" data-termcanvas-anonymous-index="{index}">'
                           f'<p>{description}</p></dd>')
            section = section[:row.start()] + original.replace(EMPTY_DESCRIPTION, replacement, 1) + section[row.end():]
            parameters[index]["documentation"] = mapping[index]
        declaration["termcanvasAnonymousParameterRepair"] = {"generator": "cjdoc-0.7.7", "descriptions": mapping}
        page.write_text(text[:start] + section + text[end:], encoding="utf-8")
        count += 1
    if count:
        docs_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return count
