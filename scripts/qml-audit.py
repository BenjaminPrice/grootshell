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

  behavior-on-handler-name
                        A Behavior on a property whose name begins with "on".
                        "on" is the signal-handler prefix, so the interceptor's
                        target resolution walks into that path and SEGFAULTS the
                        engine mid-construction — no QML error, just a crash loop
                        and a stack trace naming no file of ours. Shipped once,
                        on Theme's onAccent/onAccentContainer/onError. Animate a
                        differently-named backing property and alias the
                        Material 3 name to it.

  deep-alias            `property alias x: id.group.member` cannot resolve a
                        member of a value-type group such as anchors.

  item-shadow           Redeclaring a property an Item already has (enabled,
                        opacity, visible, ...) inside a component that derives
                        from one shadows the built-in.

  builtin-name          A .qml file whose name matches a built-in QML type. The
                        file registers a second type under that name, and any
                        file importing both QtQuick and this module then has two.
                        Shipped once, as State.qml against QtQuick's State.

  missing-import        A type defined elsewhere in this tree, used in a file
                        that never imports the module holding it. Parses, and
                        fails at load with "X is not a type" — which restart-
                        loops the shell. Shipped once, as EdgeReservation in
                        shell.qml, which imported every qs.modules.* and not
                        qs.components. Also covers SINGLETONS, which are used by
                        name rather than instantiated: those do not even fail
                        loudly — the expression throws, the binding produces
                        nothing, and the feature is quietly empty.

  duplicate-id          The same id twice in one file. QML ids are unique per
                        component; qmlformat accepts it and the engine rejects
                        it at load. Shipped once, from a delegate being wrapped
                        in a new item that kept the inner one's id.

  duplicate-handler     Two handlers for the same signal on the ROOT object of a
                        file. QML allows exactly one per signal — a second is
                        not an addition, it is "Property value set multiple
                        times" at LOAD time, which restart-loops the shell.
                        Shipped once: a panel that already had an onOpenChanged
                        for one job gained a second for another. Root scope only,
                        because two objects in a file may each legitimately
                        handle onClicked.

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
# Not anchored to the line start: `Rectangle { id: row }` is legal and was how
# the duplicate that shipped was written. The lookbehind keeps it from matching
# a property whose name merely ends in "id", such as `elementId:`.
ID_LINE = re.compile(r"(?<![\w.])id:\s*(\w+)")
IMPORT = re.compile(r"^\s*import\s+(qs(?:\.[\w.]+)?)", re.M)
INLINE_COMPONENT = re.compile(r"^\s*component\s+(\w+)\s*:", re.M)
# An object declaration: a capitalised type at the start of a line, then a brace.
# Excludes `on Foo {` and property bindings, which never start a line this way.
OBJECT_DECL = re.compile(r"^\s*([A-Z]\w*)\s*\{", re.M)
REQUIRED = re.compile(r"required\s+property\s+[\w.<>]+\s+(\w+)")
# The same, but only at a file's ROOT indentation.
#
# What a type "requires" is what a consumer of it has to fill, and that is only
# the root-level declarations. A `required property var modelData` nested twenty
# spaces deep inside a Component's own Repeater delegate belongs to that
# delegate, not to the type — reading it as the type's meant every delegate of
# that type was reported for declaring the modelData a Repeater is obliged to
# give it. Anchored on four spaces, which is what qmlformat produces and
# `nix flake check` enforces.
REQUIRED_ROOT = re.compile(r"^    required\s+property\s+[\w.<>]+\s+(\w+)", re.M)
# Anchored to four spaces: the root object's own scope. Deeper handlers belong to
# nested objects, where repeating a signal name is not merely legal but usual.
HANDLER_ROOT = re.compile(r"^    (on[A-Z]\w*)\s*:", re.M)
DELEGATE = re.compile(r"delegate:\s*([A-Z]\w*)\s*\{")
BEHAVIOR = re.compile(r"Behavior\s+on\s+([\w.]+)")
DEEP_ALIAS = re.compile(r"property\s+alias\s+\w+\s*:\s*(\w+\.\w+\.\w+)")
COMPONENT = re.compile(rf"component\s+\w+\s*:\s*{ITEM_DERIVED}\s*\{{")
PROPERTY = re.compile(r"property\s+\w+\s+(\w+)")
PRAGMA_SINGLETON = re.compile(r"^\s*pragma\s+Singleton", re.M)


COMMENT_LINE = re.compile(r"^[ \t]*//.*$", re.M)
COMMENT_BLOCK = re.compile(r"/\*.*?\*/", re.S)


def strip_comments(text: str) -> str:
    """Blank out comments, preserving length and line breaks.

    Every rule here is a regex over source text, so a comment that DESCRIBES a
    mistake reads exactly like the mistake. That is not hypothetical: the note in
    config/Theme.qml explaining why you must not write `Behavior on onAccent`
    was itself reported as a `Behavior on onAccent`.

    Characters are replaced with spaces rather than removed so that every byte
    offset — and therefore every reported line number — stays exactly where it
    was.

    Only WHOLE-LINE `//` comments are stripped. A trailing comment after code
    cannot be told from a `//` inside a string literal without parsing QML
    properly, and `"https://..."` is far too common to risk mangling. Whole-line
    comments are where the prose lives, which is all this needs to reach.
    """

    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if ch == "\n" else " " for ch in match.group(0))

    return COMMENT_LINE.sub(blank, COMMENT_BLOCK.sub(blank, text))


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
        out[path.stem] = set(REQUIRED_ROOT.findall(strip_comments(path.read_text(encoding="utf-8"))))
    return out


def audit(path: Path, required: dict[str, set[str]] | None = None) -> list[tuple[int, str, str]]:
    text = strip_comments(path.read_text(encoding="utf-8"))
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

    seen_handlers: dict[str, int] = {}
    for match in HANDLER_ROOT.finditer(text):
        name = match.group(1)
        line = line_of(text, match.start())
        if name in seen_handlers:
            findings.append(
                (
                    line,
                    "duplicate-handler",
                    f"{name} is already handled on line {seen_handlers[name]}; "
                    "QML allows one handler per signal and rejects the file at load",
                )
            )
        else:
            seen_handlers[name] = line

    seen_ids: dict[str, int] = {}
    for match in ID_LINE.finditer(text):
        name = match.group(1)
        line = line_of(text, match.start())
        if name in seen_ids:
            findings.append(
                (
                    line,
                    "duplicate-id",
                    f"id '{name}' is already used on line {seen_ids[name]}; "
                    "ids must be unique within a file",
                )
            )
        else:
            seen_ids[name] = line

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
        # A Behavior on a property whose name starts with "on" SEGFAULTS the QML
        # engine while the object is being constructed. "on" is the
        # signal-handler prefix, and the interceptor's target resolution walks
        # into that path and dies in QQmlData::deferData.
        #
        # It parses, and qmlformat is happy with it, so nothing else in the
        # toolchain sees it — this took the whole shell down with a crash loop
        # and a stack trace that named no file of ours. Bisected to a one-line
        # reproduction: a single Behavior on a property called `onTone`.
        #
        # The fix is not to rename the role. Material 3 calls these onAccent and
        # onError and the shell reads them that way everywhere. Animate a
        # backing property named something else — config/Theme.qml uses `ink*` —
        # and alias the Material name to it.
        if re.match(r"on[A-Z]", target):
            findings.append(
                (
                    line_of(text, match.start()),
                    "behavior-on-handler-name",
                    f"Behavior on '{match.group(1)}': a property whose name begins "
                    "with 'on' collides with the signal-handler prefix and crashes "
                    "the engine at construction. Animate a differently-named "
                    "backing property and alias this one to it",
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


def module_of(path: Path, root: Path) -> str:
    """The qs module a file belongs to: components/Foo.qml -> "qs.components"."""
    rel = path.parent.relative_to(root)
    return "qs." + ".".join(rel.parts) if rel.parts else "qs"


def check_imports(files: list[Path], root: Path) -> list[tuple[Path, int, str, str]]:
    """Types used without importing the module that defines them.

    Only types this tree defines are considered — anything from QtQuick or
    Quickshell is someone else's problem and resolves through its own import.
    """
    defined: dict[str, str] = {}
    # Singletons are referenced by NAME rather than instantiated, so they never
    # appear as an object declaration and the loop below cannot see them. They
    # are also most of what this tree defines.
    singletons: dict[str, str] = {}
    for f in files:
        defined[f.stem] = module_of(f, root)
        if PRAGMA_SINGLETON.search(f.read_text(encoding="utf-8")):
            singletons[f.stem] = module_of(f, root)

    findings: list[tuple[Path, int, str, str]] = []

    for f in files:
        text = f.read_text(encoding="utf-8")
        own = module_of(f, root)
        imported = set(IMPORT.findall(text))
        # Types declared inline with `component Name:` need no import.
        inline = set(INLINE_COMPONENT.findall(text))

        seen: set[str] = set()
        for match in OBJECT_DECL.finditer(text):
            name = match.group(1)
            if name in seen or name == f.stem or name in inline:
                continue
            source = defined.get(name)
            if source is None or source == own or source in imported:
                continue
            seen.add(name)
            findings.append(
                (
                    f,
                    line_of(text, match.start()),
                    "missing-import",
                    f"'{name}' is defined in {source}, which this file does not import",
                )
            )

        # The same check for singletons, which are USED rather than declared.
        #
        # `Config.configDir` in a file that does not import qs.config does not
        # fail to parse and does not fail to load — the expression simply throws
        # at evaluation, the binding that contained it silently produces nothing,
        # and whatever depended on it is empty. That is far harder to spot than
        # the "is not a type" a missing object import gives you: it shipped as a
        # keybind cheatsheet that read no file at all.
        stripped = strip_comments(text)
        for name, source in singletons.items():
            if name in seen or name == f.stem or source == own or source in imported:
                continue
            use = re.search(rf"(?<![\w.]){re.escape(name)}\s*\.", stripped)
            if not use:
                continue
            seen.add(name)
            findings.append(
                (
                    f,
                    line_of(text, use.start()),
                    "missing-import",
                    f"singleton '{name}' is defined in {source}, which this file does not import",
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

    # Cross-file, so it runs once over the whole set rather than per file.
    for path, line, rule, message in check_imports(files, root):
        print(f"{path}:{line}: {rule}: {message}", file=sys.stderr)
        total += 1

    if total:
        print(f"\nqml-audit: {total} finding(s) in {len(files)} file(s)", file=sys.stderr)
        return 1

    print(f"qml-audit: {len(files)} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
