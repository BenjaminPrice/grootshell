import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The launcher, rising from the bottom edge.
//
// Bottom rather than centre because the bottom edge is otherwise unused, and a
// panel that grows out of an edge belongs to the frame in a way a centred box
// floating over the desktop does not.
//
// Three modes, chosen by prefix rather than a mode key: plain text searches
// applications, `>` runs a command, `=` evaluates arithmetic. Prefixes keep it a
// single field with no state to get stuck in.

// Docked rather than floating: it pulls out of the bottom border with the same
// filleted junctions as the wallpaper strip, so it reads as the frame making
// room rather than as a box appearing over the desktop.
DockedPanel {
    id: root

    edge: "bottom"
    open: ShellState.launcher

    span: Math.round(Config.launcher.width * Appearance.font.scale)

    // Grows and shrinks with the result list. Animated, because the depth
    // changes on every keystroke that adds or removes a row, and an unanimated
    // panel jumping height under the text you are typing is worse than no
    // animation at all.
    depth: body.implicitHeight + padding * 2

    Behavior on depth {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutQuad
        }
    }

    readonly property string query: input.text
    readonly property bool isCommand: query.startsWith(Config.launcher.commandPrefix)
    readonly property bool isMath: query.startsWith(Config.launcher.mathPrefix)
    readonly property string term: (isCommand || isMath) ? query.slice(1).trim() : query.trim()

    onOpenChanged: {
        if (open) {
            input.text = "";
            input.forceActiveFocus();
        }
    }

    // --- Application search -------------------------------------------------
    //
    // Ranked, not filtered. A plain `includes` test puts "Disk Usage Analyzer"
    // above "Discord" for "dis" simply because of alphabetical order, which is
    // wrong every time. Prefix beats word-start beats substring.
    readonly property var results: {
        if (isCommand || isMath || !open)
            return [];

        const q = term.toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);

        if (q === "")
            return apps.slice(0, Config.launcher.maxResults);

        const scored = [];
        for (const app of apps) {
            const name = (app.name ?? "").toLowerCase();
            const generic = (app.genericName ?? "").toLowerCase();

            let score = -1;
            if (name.startsWith(q))
                score = 0;
            else if (name.split(/\s+/).some(w => w.startsWith(q)))
                score = 1;
            else if (name.includes(q))
                score = 2;
            else if (generic.includes(q))
                score = 3;

            if (score >= 0)
                scored.push({
                    app,
                    score,
                    name
                });
        }

        scored.sort((a, b) => a.score - b.score || a.name.localeCompare(b.name));
        return scored.slice(0, Config.launcher.maxResults).map(s => s.app);
    }

    property int selected: 0
    onResultsChanged: selected = 0

    function activate(): void {
        if (isMath)
            return; // the result is the answer; nothing to launch

        // Both paths go through Apps, which puts the process in its own
        // systemd scope. Launching directly leaves it in the shell's cgroup,
        // where the next `systemctl restart grootshell` kills it — see
        // services/Apps.qml.
        if (isCommand) {
            if (term)
                Apps.shell(term);
            ShellState.close("launcher");
            return;
        }

        const app = results[selected];
        if (app) {
            Apps.launchEntry(app);
            ShellState.close("launcher");
        }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        // --- Input ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Icon {
                text: root.isCommand ? "terminal" : root.isMath ? "calculate" : "search"
                color: Theme.textSecondary
                size: Appearance.font.size.lg
            }

            TextInput {
                id: input

                Layout.fillWidth: true
                font.family: Appearance.font.family.sans
                font.pixelSize: Appearance.font.size.lg
                color: Theme.text
                selectionColor: Theme.accentContainer
                selectedTextColor: Theme.onAccentContainer
                clip: true

                onAccepted: root.activate()

                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
                Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                // Tab cycles rather than moving focus — there is nowhere else to
                // put focus, and Tab wrapping is what people expect in a picker.
                Keys.onTabPressed: root.selected = root.results.length > 0 ? (root.selected + 1) % root.results.length : 0

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Search, ${Config.launcher.commandPrefix} to run, ${Config.launcher.mathPrefix} to calculate`
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.md
                    visible: input.text === ""
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
            visible: root.results.length > 0 || root.isMath
        }

        // --- Arithmetic -----------------------------------------------------
        StyledText {
            Layout.fillWidth: true
            visible: root.isMath && root.term !== ""
            text: root.evaluate(root.term)
            font.pixelSize: Appearance.font.size.xl
            color: Theme.accent
            mono: true
        }

        // --- Results --------------------------------------------------------
        Repeater {
            model: root.results

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 46
                radius: Appearance.rounding.normal
                color: index === root.selected ? Theme.accentContainer : "transparent"

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.md
                    anchors.rightMargin: Appearance.padding.md
                    spacing: Appearance.spacing.md

                    IconImage {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: index === root.selected ? Theme.onAccentContainer : Theme.text
                            font.pixelSize: Appearance.font.size.md
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.genericName ?? ""
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            visible: text !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = row.index
                    onClicked: root.activate()
                }
            }
        }
    }

    // Arithmetic only — no variables, no calls. The input is a string the user
    // typed, and handing that to a JS evaluator with a wide grammar is how a
    // launcher becomes an arbitrary code execution surface. `>` already exists
    // for running things, explicitly and visibly.
    function evaluate(expr: string): string {
        if (!/^[-+*/%^(). 0-9]+$/.test(expr))
            return "…";
        try {
            const js = expr.replace(/\^/g, "**");
            const value = Function(`"use strict"; return (${js});`)();
            if (typeof value !== "number" || !isFinite(value))
                return "…";
            return `${Math.round(value * 1e10) / 1e10}`;
        } catch (e) {
            return "…";
        }
    }
}
