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

Run over the QML tree; exits non-zero on any finding.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

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

READONLY = re.compile(r"readonly\s+property\s+\w+\s+(\w+)")
BEHAVIOR = re.compile(r"Behavior\s+on\s+([\w.]+)")
DEEP_ALIAS = re.compile(r"property\s+alias\s+\w+\s*:\s*(\w+\.\w+\.\w+)")
COMPONENT = re.compile(rf"component\s+\w+\s*:\s*{ITEM_DERIVED}\s*\{{")
PROPERTY = re.compile(r"property\s+\w+\s+(\w+)")


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def audit(path: Path) -> list[tuple[int, str, str]]:
    text = path.read_text(encoding="utf-8")
    findings: list[tuple[int, str, str]] = []

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

    total = 0
    for path in files:
        for line, rule, message in audit(path):
            print(f"{path}:{line}: {rule}: {message}", file=sys.stderr)
            total += 1

    if total:
        print(f"\nqml-audit: {total} finding(s) in {len(files)} file(s)", file=sys.stderr)
        return 1

    print(f"qml-audit: {len(files)} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
