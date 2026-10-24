#!/usr/bin/env python3
"""Static guardrails for conventions that qmllint cannot express.

Checks:
  * singleton files have a `Singleton {}` root;
  * FileView blocks keep preload/blockAllReads (and blockWrites when they own
    a JsonAdapter) after `path:`;
  * modules/services do not hardcode hex colors outside style/;
  * the en/de translation tables carry the same keys and every literal
    I18n.t("...") call site exists in the table.

No build, no imports outside the standard library; run it from anywhere:
  python3 scripts/check-qml.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QML_DIRS = ("modules", "services", "style")
ERRORS: list[str] = []


def qml_files(*dirs: str) -> list[Path]:
    files: list[Path] = []
    for name in dirs:
        files.extend(sorted((ROOT / name).glob("*.qml")))
    return files


def find_blocks(text: str, keyword: str) -> list[str]:
    """Return every balanced `keyword { ... }` block, strings/comments aware."""
    blocks: list[str] = []
    for match in re.finditer(rf"\b{re.escape(keyword)}\s*\{{", text):
        start = text.index("{", match.start())
        depth = 0
        i = start
        quote = ""
        escaped = False
        line_comment = False
        block_comment = False
        while i < len(text):
            char = text[i]
            nxt = text[i + 1] if i + 1 < len(text) else ""
            if line_comment:
                if char == "\n":
                    line_comment = False
            elif block_comment:
                if char == "*" and nxt == "/":
                    block_comment = False
                    i += 2
                    continue
            elif quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            else:
                if char == "/" and nxt == "/":
                    line_comment = True
                    i += 2
                    continue
                if char == "/" and nxt == "*":
                    block_comment = True
                    i += 2
                    continue
                if char in "\"'":
                    quote = char
                elif char == "{":
                    depth += 1
                elif char == "}":
                    depth -= 1
                    if depth == 0:
                        blocks.append(text[match.start():i + 1])
                        break
            i += 1
    return blocks


def block_after_key(text: str, key: str) -> str:
    """Return the balanced object literal assigned to `"key": { ... }`."""
    match = re.search(rf'"{re.escape(key)}"\s*:\s*\{{', text)
    if not match:
        return ""
    start = text.index("{", match.start())
    depth = 0
    i = start
    quote = ""
    escaped = False
    line_comment = False
    block_comment = False
    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
        else:
            if char == "/" and nxt == "/":
                line_comment = True
                i += 2
                continue
            if char == "/" and nxt == "*":
                block_comment = True
                i += 2
                continue
            if char in "\"'":
                quote = char
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return text[start:i + 1]
        i += 1
    return ""


def check_singletons() -> None:
    for path in qml_files("services", "style"):
        text = path.read_text(encoding="utf-8")
        if "pragma Singleton" not in text:
            continue
        if not re.search(r"^\s*Singleton\s*\{", text, re.MULTILINE):
            ERRORS.append(
                f"{path.relative_to(ROOT)}: pragma Singleton without a Singleton {{ }} root"
            )


def check_fileviews() -> None:
    for path in qml_files(*QML_DIRS):
        text = path.read_text(encoding="utf-8")
        for block in find_blocks(text, "FileView"):
            where = f"{path.relative_to(ROOT)}: FileView"
            if "path:" not in block:
                ERRORS.append(f"{where} has no path:")
                continue
            path_at = block.find("path:")
            for prop in ("preload: false", "blockAllReads: true"):
                at = block.find(prop)
                if at == -1:
                    ERRORS.append(f"{where} is missing {prop}")
                elif at < path_at:
                    ERRORS.append(f"{where}: {prop} must come after path:")
            if "JsonAdapter" in block or "writeAdapter" in block:
                at = block.find("blockWrites: true")
                if at == -1:
                    ERRORS.append(f"{where} owns a JsonAdapter but has no blockWrites: true")
                elif at < path_at:
                    ERRORS.append(f"{where}: blockWrites: true must come after path:")


def check_hardcoded_colors() -> None:
    hex_color = re.compile(r'"#[0-9a-fA-F]{3,8}"')
    paths = [ROOT / "shell.qml", *qml_files("modules", "services")]
    for path in paths:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if hex_color.search(line) and not line.lstrip().startswith("//"):
                ERRORS.append(
                    f"{path.relative_to(ROOT)}:{number}: hardcoded color {line.strip()}"
                )


def check_i18n() -> None:
    i18n = ROOT / "services" / "I18n.qml"
    text = i18n.read_text(encoding="utf-8")
    en_block = block_after_key(text, "en")
    de_block = block_after_key(text, "de")
    if not en_block or not de_block:
        ERRORS.append("services/I18n.qml: cannot find the en/de translation tables")
        return

    key_re = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:', re.MULTILINE)
    en_keys = set(key_re.findall(en_block))
    de_keys = set(key_re.findall(de_block))
    for key in sorted(en_keys - de_keys):
        ERRORS.append(f"services/I18n.qml: de misses {key!r}")
    for key in sorted(de_keys - en_keys):
        ERRORS.append(f"services/I18n.qml: en misses {key!r}")

    used: dict[str, Path] = {}
    for path in qml_files(*QML_DIRS) + [ROOT / "shell.qml"]:
        if path.name == "I18n.qml":
            continue
        source = path.read_text(encoding="utf-8")
        for match in re.finditer(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"', source):
            used[match.group(1)] = path
        for match in re.finditer(r"I18n\.t\(\s*\[(.*?)\]", source, re.DOTALL):
            for key in re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1)):
                used[key] = path
    for key, path in sorted(used.items()):
        if key not in en_keys:
            ERRORS.append(
                f"{path.relative_to(ROOT)}: I18n key {key!r} is missing from the en table"
            )


def main() -> int:
    check_singletons()
    check_fileviews()
    check_hardcoded_colors()
    check_i18n()
    if ERRORS:
        print("\n".join(ERRORS))
        print(f"\n{len(ERRORS)} problem(s).", file=sys.stderr)
        return 1
    print("OK: QML conventions and i18n tables look consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
