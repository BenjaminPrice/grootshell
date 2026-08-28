#!/usr/bin/env python3
"""Catch QML mistakes that parse cleanly and then fail at load.

qmlformat proves a file is syntactically valid, which is not the same as it
working. The errors below are all accepted by the parser and rejected by the
engine at load time — and because Quickshell exits when its config fails to
load, every one of them is a black screen on a host with no local console.

Each rule here exists because it shipped:

  behavior-on-readonly  A Behavior animates writes. A read-only property is
                        never written to, only re-evaluated, so attaching one is
                        a hard error. Shipped twice.

  deep-alias            `property alias x: id.group.member` cannot resolve a
                        member of a value-type group such as anchors.

  item-shadow           Redeclaring a property an Item already has (enabled,
                        opacity, visible, ...) inside a component that derives
                        from one shadows the built-in.

  builtin-name          A .qml file whose name matches a built-in QML type. The
                        file registers a second type under that name, and any
                        file importing both QtQuick and this module then has two.
                        Shipped once, as State.qml against QtQuick's State.

  reserved-word         A property named with a word QML reserves. Parses, then
                        fails at load with "Reserved keyword ... cannot be used
                        as a QML identifier". Shipped once, as `transient`.

  shadowed-required     A delegate redeclaring a `required property` its own base
                        type already declares. The redeclaration is a SECOND
                        property; the view fills that one and the base type's
                        bindings keep reading the original, which nobody
                        assigned. Renders an empty widget with no error.

Run over the QML tree; exits non-zero on any finding.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Words QML will not accept as an identifier. Determined by feeding each
# candidate to qmllint rather than taken from a language reference: most are
# Java-flavoured future-reserved words that no JavaScript programmer would
# expect, which is exactly why this is worth checking mechanically.
RESERVED_WORDS = frozenset(
    {
        "abstract",
        "as",
        "enum",
        "implements",
        "interface",
        "native",
        "package",
        "private",
        "protected",
        "public",
        "static",
        "synchronized",
        "throws",
        "transient",
        "volatile",
    }
)

# Properties QQuickItem already provides. Redeclaring any of these inside a
# component whose base is an Item shadows the original.
ITEM_PROPERTIES = frozenset(
    {
        "enabled",
        "opacity",
        "visible",
        "width",
        "height",
        "x",
        "y",
        "z",
        "state",
        "clip",
        "focus",
        "scale",
        "rotation",
        "parent",
        "children",
        "data",
        "anchors",
    }
)

ITEM_DERIVED = r"(?:Item|Rectangle|MouseArea|Text|Image|Row|Column|Flow|Grid)"

# Type names QtQuick / QtQml already define. A file of the same name shadows
# them wherever both are imported, which is everywhere.
BUILTIN_TYPES = frozenset(
    {
        "Item", "Rectangle", "Text", "TextInput", "TextEdit", "Image", "AnimatedImage",
        "BorderImage", "MouseArea", "Flickable", "ListView", "GridView", "PathView",
        "Repeater", "Loader", "Component", "Connections", "Binding", "Timer",
        "State", "StateGroup", "Transition", "Behavior", "Animation", "NumberAnimation",
        "ColorAnimation", "PropertyAnimation", "SequentialAnimation", "ParallelAnimation",
        "Row", "Column", "Grid", "Flow", "Positioner", "Shortcut", "FontLoader",
        "Gradient", "GradientStop", "Scale", "Rotation", "Translate", "Transform",
        "Path", "Shape", "ShapePath", "Screen", "Window", "Drag", "DropArea",
        "Accessible", "Qt", "Package", "Instantiator", "ObjectModel", "ListModel",
        "ListElement", "SoundEffect", "Audio", "Video", "Canvas", "Context2D",
    }
)

READONLY = re.compile(r"readonly\s+property\s+\w+\s+(\w+)")
REQUIRED = re.compile(r"required\s+property\s+[\w.<>]+\s+(\w+)")
DELEGATE = re.compile(r"delegate:\s*([A-Z]\w*)\s*\{")
BEHAVIOR = re.compile(r"Behavior\s+on\s+([\w.]+)")
DEEP_ALIAS = re.compile(r"property\s+alias\s+\w+\s*:\s*(\w+\.\w+\.\w+)")
COMPONENT = re.compile(rf"component\s+\w+\s*:\s*{ITEM_DERIVED}\s*\{{")
PROPERTY = re.compile(r"property\s+\w+\s+(\w+)")


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def block_at(text: str, open_brace: int) -> str:
    """Return the body of the brace block starting at `open_brace`."""
    depth = 0
    for i in range(open_brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace + 1 : i]
    return text[open_brace + 1 :]


def required_by_type(files: list[Path]) -> dict[str, set[str]]:
    """Map each local component name to the required properties it declares."""
    out: dict[str, set[str]] = {}
    for path in files:
        out[path.stem] = set(REQUIRED.findall(path.read_text(encoding="utf-8")))
    return out


def audit(path: Path, required: dict[str, set[str]] | None = None) -> list[tuple[int, str, str]]:
    text = path.read_text(encoding="utf-8")
    findings: list[tuple[int, str, str]] = []

    for match in DELEGATE.finditer(text):
        base = match.group(1)
        inherited = (required or {}).get(base)
        if not inherited:
            continue
        body = block_at(text, match.end() - 1)
        for prop in REQUIRED.finditer(body):
            if prop.group(1) in inherited:
                findings.append(
                    (
                        line_of(text, match.end() + prop.start()),
                        "shadowed-required",
                        f"'{prop.group(1)}' is already required by {base}; "
                        "redeclaring it shadows the property that type reads",
                    )
                )

    for prop in PROPERTY.finditer(text):
        if prop.group(1) in RESERVED_WORDS:
            findings.append(
                (
                    line_of(text, prop.start()),
                    "reserved-word",
                    f"'{prop.group(1)}' is a reserved word in QML and cannot name a property",
                )
            )

    if path.stem in BUILTIN_TYPES:
        findings.append(
            (
                1,
                "builtin-name",
                f"'{path.stem}' is a built-in QML type; this file shadows it",
            )
        )

    readonly = {m.group(1) for m in READONLY.finditer(text)}
    for match in BEHAVIOR.finditer(text):
        target = match.group(1).split(".")[0]
        if target in readonly:
            findings.append(
                (
                    line_of(text, match.start()),
                    "behavior-on-readonly",
                    f"Behavior on '{match.group(1)}', which is declared readonly",
                )
            )

    for match in DEEP_ALIAS.finditer(text):
        findings.append(
            (
                line_of(text, match.start()),
                "deep-alias",
                f"alias to '{match.group(1)}' reaches into a grouped property",
            )
        )

    # Only look at the body of an inline component, not the whole file — a
    # top-level Singleton may legitimately declare `enabled`.
    for match in COMPONENT.finditer(text):
        body = text[match.end() : match.end() + 2000]
        for prop in PROPERTY.finditer(body):
            if prop.group(1) in ITEM_PROPERTIES:
                findings.append(
                    (
                        line_of(text, match.end() + prop.start()),
                        "item-shadow",
                        f"'{prop.group(1)}' shadows the same property on Item",
                    )
                )

    return findings


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = sorted(p for p in root.rglob("*.qml") if ".git" not in p.parts)

    if not files:
        print(f"qml-audit: no QML found under {root}", file=sys.stderr)
        return 1

    required = required_by_type(files)

    total = 0
    for path in files:
        for line, rule, message in audit(path, required):
            print(f"{path}:{line}: {rule}: {message}", file=sys.stderr)
            total += 1

    if total:
        print(f"\nqml-audit: {total} finding(s) in {len(files)} file(s)", file=sys.stderr)
        return 1

    print(f"qml-audit: {len(files)} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
